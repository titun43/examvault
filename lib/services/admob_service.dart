// =============================================================================
// ExamVault - AdMob Service
// Banner, Interstitial, Rewarded, Native Ads
// =============================================================================

import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';

class AdMobService {
  AdMobService._();

  static bool _initialized = false;
  static InterstitialAd? _interstitialAd;
  static RewardedAd? _rewardedAd;
  static AppOpenAd? _appOpenAd;
  static int _interstitialLoadAttempts = 0;
  static int _rewardedLoadAttempts = 0;

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

  static String get rewardedAdUnitId =>
      AppConfig.admobTestMode ? AppConfig.testRewardedAdUnitId : AppConfig.rewardedAdUnitId;

  static String get nativeAdUnitId =>
      AppConfig.admobTestMode ? AppConfig.testNativeAdUnitId : AppConfig.nativeAdUnitId;

  static String get appOpenAdUnitId =>
      AppConfig.admobTestMode ? AppConfig.testAppOpenAdUnitId : AppConfig.appOpenAdUnitId;

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

  // ==================== REWARDED AD ====================
  static void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      adLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoadAttempts = 0;
        },
        onAdFailedToLoad: (error) {
          _rewardedLoadAttempts++;
          _rewardedAd = null;
          if (_rewardedLoadAttempts < 3) {
            loadRewardedAd();
          }
        },
      ),
    );
  }

  static Future<bool> showRewardedAd({
    required void Function(int amount) onReward,
  }) async {
    if (_rewardedAd == null) {
      loadRewardedAd();
      return false;
    }
    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onReward(reward.amount.toInt());
      },
    );
    _rewardedAd = null;
    loadRewardedAd();
    return true;
  }

  // ==================== APP OPEN AD ====================
  static void loadAppOpenAd() {
    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
        },
      ),
    );
  }

  static Future<bool> showAppOpenAd() async {
    if (_appOpenAd == null) {
      loadAppOpenAd();
      return false;
    }
    await _appOpenAd!.show();
    _appOpenAd = null;
    loadAppOpenAd();
    return true;
  }

  // ==================== CLEANUP ====================
  static void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _appOpenAd?.dispose();
  }
}
