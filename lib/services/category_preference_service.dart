// =============================================================================
// ExamVault - Category Preference Service
// =============================================================================
// Handles the "which exam categories does this user care about" preference
// used by the first-run onboarding flow and the Home screen filter.
//
// Storage strategy:
//   - Logged-in users: stored in Firestore under users/{uid}.preferences
//     .selectedCategoryIds (via AuthService.updateProfileExtended), so it
//     follows the user across devices. Read from the in-memory UserModel.
//   - Guests (not signed in): stored locally in SharedPreferences, since
//     there's no user doc to write to yet.
//   - The "have we shown onboarding" flag is ALWAYS local (SharedPreferences)
//     — it just controls whether the picker pops up again on this device.
// =============================================================================

import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class CategoryPreferenceService {
  static const _guestSelectedKey = 'guest_selected_category_ids';
  static const _onboardingDoneKey = 'category_onboarding_done';

  /// Returns the user's saved category selection.
  /// For a logged-in user, pass their [user] model (reads preferences map).
  /// For a guest, pass null — reads from SharedPreferences instead.
  static Future<List<String>> getSelectedCategoryIds(UserModel? user) async {
    if (user != null) {
      final raw = user.preferences['selectedCategoryIds'];
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return const [];
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_guestSelectedKey) ?? const [];
  }

  /// Saves the selection. For a logged-in [user], writes to Firestore
  /// (caller is responsible for refreshing AuthProvider afterwards so the
  /// UI picks up the change). For a guest, writes locally only.
  static Future<void> saveSelectedCategoryIds(
    List<String> categoryIds, {
    UserModel? user,
  }) async {
    if (user != null) {
      await AuthService.updateProfileExtended(
        userId: user.id,
        preferences: {'selectedCategoryIds': categoryIds},
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_guestSelectedKey, categoryIds);
    }
    await markOnboardingComplete();
  }

  /// Whether the first-run category picker has already been shown/completed
  /// on this device. This flag is intentionally device-local (not tied to
  /// the account) so re-installs or new devices see the picker again.
  static Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingDoneKey) ?? false;
  }

  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingDoneKey, true);
  }

  /// Merges a guest's locally-saved selection into their account right after
  /// they sign in (best-effort, never throws) — so picking categories as a
  /// guest isn't lost when they create an account.
  static Future<void> migrateGuestSelectionToUser(UserModel user) async {
    try {
      final existing = await getSelectedCategoryIds(user);
      if (existing.isNotEmpty) return; // account already has a selection
      final prefs = await SharedPreferences.getInstance();
      final guestSelection = prefs.getStringList(_guestSelectedKey);
      if (guestSelection == null || guestSelection.isEmpty) return;
      await AuthService.updateProfileExtended(
        userId: user.id,
        preferences: {'selectedCategoryIds': guestSelection},
      );
    } catch (_) {
      // Best-effort only — never block sign-in on this.
    }
  }
}
