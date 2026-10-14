// =============================================================================
// ExamVault - Ad Frequency Controller
// Controls how often interstitial ads are shown so users don't get annoyed.
// Rules (v1.57.0+90 — more aggressive per developer request):
//   - Minimum 2 actions between interstitial ads (was 3)
//   - Minimum 30 seconds between interstitial ads (was 60)
//   - Premium users never see ads (checked in AdMobService)
// =============================================================================

class AdFrequencyController {
  AdFrequencyController._();

  static int _actionsSinceLastAd = 0;
  static DateTime? _lastAdShownTime;
  static const int _minActionsBetweenAds = 2;
  static const Duration _minTimeBetweenAds = Duration(seconds: 30);

  /// Call this when a user performs an action that COULD trigger an ad.
  /// Returns true if an ad should be shown (enough actions + time passed).
  static bool shouldShowInterstitial() {
    _actionsSinceLastAd++;

    // Not enough actions since last ad
    if (_actionsSinceLastAd < _minActionsBetweenAds) {
      return false;
    }

    // Not enough time since last ad
    if (_lastAdShownTime != null) {
      final elapsed = DateTime.now().difference(_lastAdShownTime!);
      if (elapsed < _minTimeBetweenAds) {
        return false;
      }
    }

    // Show ad and reset counters
    _actionsSinceLastAd = 0;
    _lastAdShownTime = DateTime.now();
    return true;
  }

  /// Reset counters (e.g. on logout)
  static void reset() {
    _actionsSinceLastAd = 0;
    _lastAdShownTime = null;
  }
}
