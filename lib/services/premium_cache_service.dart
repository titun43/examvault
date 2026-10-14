// =============================================================================
// ExamVault - Premium Cache Service (User-Specific Local Cache)
// =============================================================================
// Persistent, USER-SPECIFIC local cache for premium subscription status,
// backed by SharedPreferences.
//
// WHY THIS EXISTS:
// After a successful Razorpay payment, the backend webhook takes a few
// seconds to grant the entitlement in the Neon PostgreSQL database. During
// that window, if the app restarts or the user navigates back, loadUserData()
// reads from Firestore (which may not have the premium flag yet) or an access
// check hits the backend (which doesn't have the entitlement yet) — and the
// user sees "Locked" for a few seconds. This cache closes that gap by giving
// the UI an instant, persistent, user-specific premium flag.
//
// USER-SPECIFIC KEYS (prevents account mixing):
//   isPremium_${userId}      — bool, true after a server-verified payment
//   premiumExpiry_${userId}  — ISO8601 string, subscription expiry
//   premiumPlanId_${userId}  — String, the plan ID purchased
//
// If a DIFFERENT user logs into the same device, the app checks
// isPremium_${newUserId} — they do NOT inherit the previous user's premium.
//
// SYNC STRATEGY (security):
// On every app launch / login, AuthProvider.loadUserData() fetches the
// REAL-TIME status from the Neon DB (via AccessService.checkPremiumOnly() →
// backend API) and OVERWRITES this local cache with the truth. The cache is
// only an optimistic bridge for the first few seconds after launch / after a
// payment — never the source of truth.
//
// The source of truth is ALWAYS the Neon PostgreSQL database (accessed via
// the backend API). This cache only mirrors it locally for instant UX.
// =============================================================================

import 'package:shared_preferences/shared_preferences.dart';

class PremiumCacheService {
  PremiumCacheService._();

  // Key builders — every key is scoped to a specific userId so a different
  // user logging into the same device never reads another user's premium.
  // Example: isPremium_abc123def456, premiumExpiry_abc123def456
  static String _isPremiumKey(String userId) => 'isPremium_$userId';
  static String _expiryKey(String userId) => 'premiumExpiry_$userId';
  static String _planIdKey(String userId) => 'premiumPlanId_$userId';

  /// Write the premium status to the local cache. Call this in the Razorpay
  /// onSuccess callback AFTER the backend verify confirms the payment
  /// (i.e. from AuthProvider.markPremium()).
  ///
  /// [userId]  — the Firebase Auth UID of the user who paid.
  /// [expiry]  — when the subscription expires (null = never / one-off).
  /// [planId]  — the purchased plan ID (for display / analytics).
  static Future<void> setPremium({
    required String userId,
    DateTime? expiry,
    String? planId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isPremiumKey(userId), true);
      if (expiry != null) {
        await prefs.setString(_expiryKey(userId), expiry.toIso8601String());
      } else {
        await prefs.remove(_expiryKey(userId));
      }
      if (planId != null) {
        await prefs.setString(_planIdKey(userId), planId);
      } else {
        await prefs.remove(_planIdKey(userId));
      }
    } catch (e) {
      print('[PremiumCache] setPremium failed (non-fatal): $e');
      // Non-fatal — the in-memory _user update in markPremium() still gives
      // the user immediate access for this session. The cache just won't
      // survive a restart, so on next launch the backend sync will restore it.
    }
  }

  /// Read the cached premium status for [userId]. Returns true ONLY if the
  /// cache says premium AND the cached expiry (if any) is still in the future.
  ///
  /// This is the INSTANT check used on app launch / login to prevent the
  /// "Locked" flash before the real-time Neon DB fetch completes.
  static Future<bool> isPremiumCached(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool(_isPremiumKey(userId)) ?? false;
      if (!isPremium) return false;
      // Verify the cached expiry hasn't passed.
      final expiryStr = prefs.getString(_expiryKey(userId));
      if (expiryStr != null) {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry != null && expiry.isBefore(DateTime.now())) {
          // Cached premium has expired — clear it and return false.
          await clearPremium(userId);
          return false;
        }
      }
      return true;
    } catch (e) {
      print('[PremiumCache] isPremiumCached failed (non-fatal): $e');
      return false;
    }
  }

  /// Read the cached expiry for [userId] (null if not set).
  static Future<DateTime?> getCachedExpiry(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryStr = prefs.getString(_expiryKey(userId));
      if (expiryStr == null) return null;
      return DateTime.tryParse(expiryStr);
    } catch (_) {
      return null;
    }
  }

  /// Read the cached plan ID for [userId].
  static Future<String?> getCachedPlanId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_planIdKey(userId));
    } catch (_) {
      return null;
    }
  }

  /// Clear the premium cache for [userId]. Call this when the real-time Neon
  /// DB fetch says the user is NOT premium (subscription expired / cancelled
  /// / refunded). This keeps the local cache in sync with the source of truth
  /// and prevents a stale "true" from giving a lapsed user free access.
  static Future<void> clearPremium(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isPremiumKey(userId));
      await prefs.remove(_expiryKey(userId));
      await prefs.remove(_planIdKey(userId));
    } catch (e) {
      print('[PremiumCache] clearPremium failed (non-fatal): $e');
    }
  }
}
