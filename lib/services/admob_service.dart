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
    if (_initialized && AppConfig.admobTestMode) {
      try {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
          ),
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
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0;
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
  }

  static Future<bool> showInterstitialAd() async {
    if (!_initialized) return false;
    if (_interstitialAd == null) {
      loadInterstitialAd();
      return false;
    }
    try {
      await _interstitialAd!.show();
    } catch (e) {
      print('showInterstitialAd failed (non-fatal): $e');
    }
    _interstitialAd = null;
    loadInterstitialAd();
    return true;
  }

  // ==================== CLEANUP ====================
  static void dispose() {
    _interstitialAd?.dispose();
  }
}
