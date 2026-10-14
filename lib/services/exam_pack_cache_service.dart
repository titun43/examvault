// =============================================================================
// ExamVault - Exam Pack Cache Service (User-Specific Local Cache)
// =============================================================================
// Persistent, USER-SPECIFIC local cache for exam-pack (category) purchase
// status, backed by SharedPreferences. This is the category-access equivalent
// of PremiumCacheService — it mirrors the same pattern so an exam-pack buyer
// gets an INSTANT "Start Test" button (no "Locked" / "Buy" flash) on every
// screen open, without waiting for the 300-900ms server access-check.
//
// WHY THIS EXISTS:
// The in-memory AccessService cache expires after 120s, and the Firestore
// `purchasedCategoryIds` list is the source of truth but the test list screen
// only consulted the server-side `_serverHasExamPackAccess` flag (which starts
// false and flips true only after a network round-trip). During that window,
// an exam-pack buyer saw a brief "Buy" flash on every test in the category
// they already paid for. This cache closes that gap by giving the UI an
// instant, persistent, user-specific list of unlocked categoryIds.
//
// USER-SPECIFIC KEYS (prevents account mixing):
//   examPackCategories_${userId}  — List<String> of categoryIds the user has
//                                   unlocked via an exam-pack purchase.
//
// If a DIFFERENT user logs into the same device, the app reads
// examPackCategories_${newUserId} — they do NOT inherit the previous user's
// unlocked categories.
//
// SYNC STRATEGY (security):
// On every successful AccessService.checkCategoryAccess() call, the cache is
// refreshed: if the server says ALLOWED, the categoryId is ADDED; if the
// server says DENIED, the categoryId is REMOVED. The cache is only an
// optimistic bridge — never the source of truth. The source of truth is the
// Neon PostgreSQL database (accessed via the backend API).
// =============================================================================

import 'package:shared_preferences/shared_preferences.dart';

class ExamPackCacheService {
  ExamPackCacheService._();

  // Key builder — scoped to a specific userId so a different user logging
  // into the same device never reads another user's unlocked categories.
  // Example: examPackCategories_abc123def456
  static String _key(String userId) => 'examPackCategories_$userId';

  /// Returns the list of categoryIds cached as unlocked for [userId].
  /// This is the INSTANT check used on screen open to prevent the "Buy" flash
  /// before the real-time server access-check completes.
  static Future<List<String>> getCachedCategoryIds(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key(userId));
      return list ?? const [];
    } catch (e) {
      print('[ExamPackCache] getCachedCategoryIds failed (non-fatal): $e');
      return const [];
    }
  }

  /// Returns true if [categoryId] is cached as unlocked for [userId].
  static Future<bool> hasCategoryAccess({
    required String userId,
    required String categoryId,
  }) async {
    if (categoryId.isEmpty) return false;
    final ids = await getCachedCategoryIds(userId);
    return ids.contains(categoryId);
  }

  /// Mark [categoryId] as unlocked for [userId] in the local cache. Call this
  /// in the Razorpay onSuccess callback for exam-pack purchases (from
  /// AuthProvider.addPurchasedCategory) AND whenever a server access-check
  /// returns ALLOWED for an exam-pack resource.
  static Future<void> addCategory({
    required String userId,
    required String categoryId,
  }) async {
    if (categoryId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key(userId)) ?? <String>[];
      if (!list.contains(categoryId)) {
        list.add(categoryId);
        await prefs.setStringList(_key(userId), list);
      }
    } catch (e) {
      print('[ExamPackCache] addCategory failed (non-fatal): $e');
      // Non-fatal — the in-memory UserModel update in addPurchasedCategory()
      // still gives the user immediate access for this session. The cache
      // just won't survive a restart, so on next launch the server sync will
      // restore it.
    }
  }

  /// Remove [categoryId] from the unlocked cache for [userId]. Call this when
  /// a server access-check returns DENIED for a category that was previously
  /// cached as unlocked (e.g. refund, expiry). This keeps the local cache in
  /// sync with the source of truth and prevents a stale "unlocked" from
  /// giving a lapsed/refunded user free access.
  static Future<void> removeCategory({
    required String userId,
    required String categoryId,
  }) async {
    if (categoryId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key(userId)) ?? <String>[];
      if (list.contains(categoryId)) {
        list.remove(categoryId);
        await prefs.setStringList(_key(userId), list);
      }
    } catch (e) {
      print('[ExamPackCache] removeCategory failed (non-fatal): $e');
    }
  }

  /// Replace the entire cached list for [userId]. Used when the server returns
  /// a fresh decision and we want to reconcile. Pass the full list of
  /// categoryIds the user currently has unlocked.
  static Future<void> setCategoryIds({
    required String userId,
    required List<String> categoryIds,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key(userId), categoryIds);
    } catch (e) {
      print('[ExamPackCache] setCategoryIds failed (non-fatal): $e');
    }
  }

  /// Clear the entire exam-pack cache for [userId]. Call this on logout is
  // NOT needed (keys are user-specific), but can be used for debugging or
  // a "reset access" admin action.
  static Future<void> clearAll(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (e) {
      print('[ExamPackCache] clearAll failed (non-fatal): $e');
    }
  }
}
