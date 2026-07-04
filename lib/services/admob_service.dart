// =============================================================================
// ExamVault - AdMob Service
// Banner + Interstitial Ads (most reliable google_mobile_ads 4.0.0 API)
// CRASH-SAFETY (v1.13+): AdMob native SDK can crash the app at the NATIVE
// level (below Dart's runZonedGuarded) if MobileAds.initialize() throws or
// if a BannerAd is created before init completes. We now:
//   1. Track _initialized so BannerAdWidget never loads an ad before init.
//   2. Wrap initialize() in its own try/catch (main.dart already wraps it,
//      but belt-and-suspenders here too).
//   3. Expose isInitialized getter for widgets to check before loading.
// =============================================================================

import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';

class AdMobService {
  AdMobService._();

  static bool _initialized = false;
  static InterstitialAd? _interstitialAd;
  static int _interstitialLoadAttempts = 0;

  /// True only after MobileAds.initialize() completed successfully.
  /// BannerAdWidget checks this before creating a BannerAd, so an ad is
  /// NEVER created before the SDK is ready (which would crash natively).
  static bool get isInitialized => _initialized;

  // ==================== INITIALIZE ====================
  static Future<void> initialize() async {
    if (_initialized) return;

    // MASTER KILL SWITCH — when admobEnabled is false, do NOT touch the
    // native AdMob SDK at all. Calling MobileAds.instance.initialize() can
    // crash the app natively (below Dart's runZonedGuarded) if the SDK /
    // ad units are not ready, so we short-circuit here entirely.
    if (!AppConfig.admobEnabled) {
      _initialized = false;
      print('AdMob disabled via AppConfig.admobEnabled — skipping SDK init.');
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      // AdMob init failed (e.g. Google Play Services missing on the device,
      // or network). We MUST NOT crash — set _initialized=false so
      // BannerAdWidget skips loading ads entirely.
      _initialized = false;
      print('AdMob initialize failed (non-fatal, ads disabled): $e');
    }

    // Set test device if in test mode — best-effort, don't crash.
    // NOTE: Google's SAMPLE test ad unit IDs (ca-app-pub-3940256099942544/...)
    // always serve test ads on ANY device, so we do NOT need to register a
    // test device ID here. The previous code passed the literal string
    // 'YOUR_TEST_DEVICE_ID', which matched no real device and was misleading.
    // We keep the call (harmless) but pass an empty list. If you later switch
    // to YOUR OWN real ad unit IDs while still in test mode, add the real
    // device IDs here (logcat prints "Use RequestConfiguration.Builder
    // .setTestDeviceIds(Arrays.asList("DEVICE-HASH"))" on first run) so real
    // devices are flagged as test devices and never show live (policy-violating)
    // impressions.
    if (_initialized && AppConfig.admobTestMode) {
      try {
        await MobileAds.instance.updateRequestConfiguration(
          const RequestConfiguration(testDeviceIds: []),
        );
      } catch (e) {
        print('AdMob test-device config failed (non-fatal): $e');
      }
    }
  }

  // ==================== AD UNIT IDs ====================
  static String get bannerAdUnitId =>
      AppConfig.admobTestMode ? AppConfig.testBannerAdUnitId : AppConfig.bannerAdUnitId;

  static String get interstitialAdUnitId =>
      AppConfig.admobTestMode ? AppConfig.testInterstitialAdUnitId : AppConfig.interstitialAdUnitId;

  // ==================== BANNER AD ====================
  static BannerAd createBannerAd({
    AdSize size = AdSize.banner,
    void Function(Ad ad)? onAdLoaded,
    void Function(Ad ad, LoadAdError error)? onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
  }

  // ==================== INTERSTITIAL AD ====================
  static void loadInterstitialAd() {
    if (!_initialized) return; // don't try if SDK isn't ready
    if (!AppConfig.admobEnabled) return; // master kill switch
    try {
      InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _interstitialLoadAttempts = 0;

            // CRASH FIX (Jul 4, 2026): the previous crash was caused by
            // showing an interstitial WITHOUT a fullScreenContentCallback —
            // when the ad was dismissed/failed, nothing disposed it or
            // cleared our reference, leaving the native Activity in a
            // broken state that could crash the app. We now always wire
            // these callbacks so dismiss/failure is handled cleanly and a
            // fresh ad is preloaded for next time.
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _interstitialAd = null;
                loadInterstitialAd();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _interstitialAd = null;
                loadInterstitialAd();
              },
            );
          },
          onAdFailedToLoad: (error) {
            _interstitialLoadAttempts++;
            _interstitialAd = null;
            if (_interstitialLoadAttempts < 3) {
              loadInterstitialAd();
            }
          },
        ),
      );
    } catch (e) {
      print('loadInterstitialAd failed (non-fatal): $e');
    }
  }

  /// True once a preloaded interstitial is ready to show immediately.
  static bool get isInterstitialReady => _interstitialAd != null;

  static Future<bool> showInterstitialAd() async {
    if (!_initialized) return false;
    if (!AppConfig.admobEnabled) return false; // master kill switch
    if (_interstitialAd == null) {
      loadInterstitialAd();
      return false;
    }
    try {
      // NOTE: .show() itself completes immediately after presenting the ad —
      // the actual dismiss/failure is handled by fullScreenContentCallback
      // above (wired in onAdLoaded), NOT by awaiting this call.
      await _interstitialAd!.show();
      return true;
    } catch (e) {
      // Non-fatal: clear the stale reference and preload the next one so a
      // broken ad instance never blocks future test submissions.
      print('showInterstitialAd failed (non-fatal): $e');
      _interstitialAd = null;
      loadInterstitialAd();
      return false;
    }
  }

  // ==================== CLEANUP ====================
  static void dispose() {
    _interstitialAd?.dispose();
  }
}
