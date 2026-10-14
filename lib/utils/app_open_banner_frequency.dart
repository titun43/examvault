// =============================================================================
// ExamVault - App Open Banner Frequency Controller
// =============================================================================
// Decides whether the app-open banner should be shown on THIS app launch,
// based on the banner's [frequency] setting and a local last-shown record.
//
// Rules:
//   - everyOpen      : always returns true (no local tracking needed).
//   - oncePerSession : tracked via an in-memory flag (resets when the app
//                      process restarts). Returns true only on the FIRST
//                      call within the current process.
//   - oncePerDay     : tracked via SharedPreferences (persists across
//                      restarts). Returns true only if the banner has not
//                      been shown yet today (calendar day, local time).
//
// Urgent override: if the banner has [isUrgent] = true, frequency cap is
// ignored and the banner is always shown (admin's "high priority" tool).
//
// After the banner is actually shown, the caller MUST invoke
// [markShown] so the next call within the same period returns false.
// =============================================================================

import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_open_banner_model.dart';

class AppOpenBannerFrequencyController {
  AppOpenBannerFrequencyController._();

  // In-memory flag for oncePerSession — resets when the app process dies.
  static bool _shownThisSession = false;

  static const String _prefsKeyPrefix = 'app_open_banner_last_shown_';

  /// Returns true if the banner should be shown now, given its frequency
  /// setting and the last-shown record. Returns false if the banner was
  /// already shown within the current period.
  static Future<bool> shouldShow(AppOpenBannerModel banner) async {
    // Urgent override — always show.
    if (banner.isUrgent) return true;

    switch (banner.frequency) {
      case AppOpenBannerFrequency.everyOpen:
        return true;
      case AppOpenBannerFrequency.oncePerSession:
        return !_shownThisSession;
      case AppOpenBannerFrequency.oncePerDay:
        final prefs = await SharedPreferences.getInstance();
        final key = '$_prefsKeyPrefix${banner.id}';
        final lastMs = prefs.getInt(key) ?? 0;
        if (lastMs == 0) return true;
        final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
        final now = DateTime.now();
        // Same calendar day (local time)?
        if (last.year == now.year &&
            last.month == now.month &&
            last.day == now.day) {
          return false;
        }
        return true;
    }
  }

  /// Marks the banner as shown NOW. Must be called AFTER the banner dialog
  /// has actually been displayed to the user.
  static Future<void> markShown(AppOpenBannerModel banner) async {
    _shownThisSession = true;
    if (banner.frequency == AppOpenBannerFrequency.oncePerDay) {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefsKeyPrefix${banner.id}';
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    }
    // For urgent / everyOpen / oncePerSession we don't need prefs.
  }
}
