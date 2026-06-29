// =============================================================================
// ExamVault - AdMob Service
// Banner + Interstitial Ads (most reliable google_mobile_ads 4.0.0 API)
// =============================================================================

import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';

class AdMobService {
  AdMobService._();

  static bool _initialized = false;
  static InterstitialAd? _interstitialAd;
  static int _interstitialLoadAttempts = 0;

  // ==================== INITIALIZE ====================
  static Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;

    // Set test device if in test mode
    if (AppConfig.admobTestMode) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
        ),
      );
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
    if (_interstitialAd == null) {
      loadInterstitialAd();
      return false;
    }
    await _interstitialAd!.show();
    _interstitialAd = null;
    loadInterstitialAd();
    return true;
  }

  // ==================== CLEANUP ====================
  static void dispose() {
    _interstitialAd?.dispose();
  }
}
