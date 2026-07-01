// =============================================================================
// EXAMVAULT - App Configuration  (REAL VALUES — DO NOT COMMIT PUBLICLY)
// =============================================================================
// All real API keys, AdMob IDs, Firebase config, Razorpay keys, and signing
// info have been entered by the app owner. Treat this file as sensitive.
// =============================================================================

class AppConfig {
  AppConfig._();

  // ==================== APP INFO ====================
  static const String appName = 'ExamVault';
  static const String appDisplayName = 'ExamVault - MCQ Mock Tests';
  static const String packageName = 'com.examvault.education';
  static const String version = '1.0.0';
  static const int versionCode = 1;

  // Owner / contact
  static const String ownerEmail = 'lkstudeoandcomputering@gmail.com';

  // ==================== FIREBASE ====================
  // NEW Firebase project: EXAMVAULTNEW (created fresh for this app).
  // On Android, google-services.json is the source of truth. Values below are
  // used for explicit FirebaseOptions init on non-Android platforms / fallback.
  static const String firebaseProjectId = 'examvaultnew';
  static const String firebaseApiKey = 'AIzaSyBKEUGs9r7Q71q7vCIh3Pz_mletXQCok6E';
  static const String firebaseAppId =
      '1:1047596633370:android:30d6b88cfed4b0bce8b0a3';
  static const String firebaseStorageBucket = 'examvaultnew.firebasestorage.app';
  static const String firebaseMessagingSenderId = '1047596633370';
  static const String firebaseAuthDomain = 'examvaultnew.firebaseapp.com';

  // SHA-1 fingerprint of the release signing certificate (added to Firebase).
  // This MUST match the fingerprint of android/app/examvault-release.keystore.
  // Verified value (Jul 1, 2026):
  //   BA:56:A6:05:A0:D8:A3:E1:81:75:C7:33:98:31:74:EF:C4:71:6A:6E
  // To re-verify:
  //   keytool -list -v -keystore android/app/examvault-release.keystore \
  //     -storepass 'ExamVault2026!'
  // If you regenerate the keystore, update this AND add the new SHA-1 to:
  //   Firebase Console → Project Settings → SHA certificate fingerprints
  //   Then download a fresh google-services.json.
  static const String releaseSha1 =
      'BA:56:A6:05:A0:D8:A3:E1:81:75:C7:33:98:31:74:EF:C4:71:6A:6E';

  // ==================== ADMOB ====================
  // Real AdMob IDs (production). Set admobTestMode=false before release.
  static const bool admobTestMode = false;

  // Test AdMob IDs (Google sample — for development only)
  static const String testAdmobAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const String testNativeAdUnitId = 'ca-app-pub-3940256099942544/2247696110';
  static const String testAppOpenAdUnitId = 'ca-app-pub-3940256099942544/9257395921';

  // ===== REAL AdMob IDs (provided by owner) =====
  static const String admobAppId = 'ca-app-pub-1742730064755213~7890219994';
  static const String bannerAdUnitId = 'ca-app-pub-1742730064755213/4499859652';
  static const String interstitialAdUnitId = 'ca-app-pub-1742730064755213/5520307609';
  // Rewarded / Native / AppOpen — reuse interstitial slot for now; create
  // dedicated ad units in AdMob console and replace when available.
  static const String rewardedAdUnitId = 'ca-app-pub-1742730064755213/5520307609';
  static const String nativeAdUnitId = 'ca-app-pub-1742730064755213/4499859652';
  static const String appOpenAdUnitId = 'ca-app-pub-1742730064755213/5520307609';

  // Active getters
  static String get activeAdmobAppId => admobTestMode ? testAdmobAppId : admobAppId;
  static String get activeBannerAdUnitId =>
      admobTestMode ? testBannerAdUnitId : bannerAdUnitId;
  static String get activeInterstitialAdUnitId =>
      admobTestMode ? testInterstitialAdUnitId : interstitialAdUnitId;
  static String get activeRewardedAdUnitId =>
      admobTestMode ? testRewardedAdUnitId : rewardedAdUnitId;
  static String get activeNativeAdUnitId =>
      admobTestMode ? testNativeAdUnitId : nativeAdUnitId;
  static String get activeAppOpenAdUnitId =>
      admobTestMode ? testAppOpenAdUnitId : appOpenAdUnitId;

  // ==================== RAZORPAY ====================
  // Live mode is enabled — real money will be charged.
  static const bool razorpayTestMode = false;

  // Test Keys (sandbox)
  static const String razorpayTestKeyId = 'rzp_test_XXXXXXXXXX';
  static const String razorpayTestKeySecret = 'XXXXXXXXXXXXXXXXXXXXXX';

  // ===== LIVE Keys (provided by owner) =====
  static const String razorpayLiveKeyId = 'rzp_live_T2FtqmiTmWAWRW';
  static const String razorpayLiveKeySecret = 'bm7ZbG2UEIRmQzoKcJXRWG2i';

  // Active getters — key_id goes in the app; key_secret should ideally be on
  // a backend for signature verification. For now, local verification is used.
  static String get razorpayKeyId =>
      razorpayTestMode ? razorpayTestKeyId : razorpayLiveKeyId;
  static String get razorpayKeySecret =>
      razorpayTestMode ? razorpayTestKeySecret : razorpayLiveKeySecret;

  // Subscription Plan IDs (create these in Razorpay Dashboard -> Subscriptions)
  static const String monthlyPlanId = 'plan_monthly_examvault';
  static const String quarterlyPlanId = 'plan_quarterly_examvault';
  static const String yearlyPlanId = 'plan_yearly_examvault';

  // ==================== KEYSTORE / SIGNING ====================
  // Used by android/key.properties — DO NOT put these in source control.
  // These are documented here for the owner's reference only.
  //   Keystore file : examvault-release.keystore
  //   Store password: ExamVault2026!
  //   Key alias     : examvault
  //   Key password  : ExamVault2026!
  //   DName         : CN=ExamVault, O=ExamVault, C=IN
  //   SHA-1         : (run keytool -list -v on the keystore to get it)

  // ==================== CONTACT & LEGAL ====================
  static const String supportEmail = 'lkstudeoandcomputering@gmail.com';
  static const String privacyPolicyUrl =
      'https://examvault.app/privacy';
  static const String termsUrl = 'https://examvault.app/terms';
  static const String refundPolicyUrl = 'https://examvault.app/refund';
  static const String websiteUrl = 'https://examvault.app';
  static const String companyName = 'ExamVault';

  // ==================== PRICING (INR) ====================
  static const int premiumMonthlyPrice = 99;
  static const int premiumQuarterlyPrice = 249;
  static const int premiumYearlyPrice = 799;

  // ==================== PREMIUM FEATURES ====================
  static const List<String> premiumFeatures = [
    'Unlimited Mock Tests',
    'Detailed Solutions',
    'Performance Analytics',
    'Ad-Free Experience',
    'Priority Support',
    'Download PDFs',
    'Previous Year Papers',
    'AI Performance Insights',
  ];

  // ==================== EXAM CATEGORIES ====================
  static const List<String> examCategories = [
    'Railway',
    'SSC',
    'UPSC',
    'Banking',
    'ADRE',
    'State Exams',
  ];

  // ==================== NOTIFICATION ====================
  static const String dailyQuizNotificationTime = '08:00';
  static const bool testResultNotification = true;
  static const bool currentAffairsNotification = true;
}
