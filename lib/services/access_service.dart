// =============================================================================
// ExamVault - Access Service (centralized entitlement checks)
// =============================================================================
// The UI calls this BEFORE showing locked content. It hits the backend's
// /api/payments/access-check endpoint, which is the single source of truth
// for whether a user can open a test / subject / category / "all" (premium).
//
// Decisions are cached in-memory for 60 seconds per (userId, resource) so
// scrolling a list doesn't hammer the API. Call [clearCache] after a
// successful purchase so the next access check is fresh.
// =============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'payment_api_service.dart';

/// Immutable access decision returned by [AccessService].
///
/// `allowed`     — true if the user can open the resource RIGHT NOW.
/// `reason`      — short machine-readable reason string from the backend
///                 (e.g. 'premium_required', 'not_purchased', 'expired',
///                 'owned', 'free'). The UI uses this to pick the right CTA.
/// `grantedBy`   — what granted access (e.g. 'PREMIUM_SUBSCRIPTION',
///                 'TEST_PURCHASE', 'SUBJECT_PACK', 'EXAM_PACK', 'FREE').
/// `sourceId`    — id of the granting payment / entitlement (nullable).
/// `expiresAt`   — when the entitlement expires (nullable; for one-off
///                 purchases like TEST_PURCHASE this is null = never).
class AccessDecision {
  final bool allowed;
  final String reason;
  final String? grantedBy;
  final String? sourceId;
  final DateTime? expiresAt;

  const AccessDecision({
    required this.allowed,
    required this.reason,
    this.grantedBy,
    this.sourceId,
    this.expiresAt,
  });

  factory AccessDecision.fromMap(Map<String, dynamic> m) {
    return AccessDecision(
      allowed: (m['allowed'] as bool?) ?? false,
      reason: (m['reason'] as String?) ?? '',
      grantedBy: m['grantedBy'] as String?,
      sourceId: m['sourceId'] as String?,
      expiresAt: m['expiresAt'] is String
          ? DateTime.tryParse(m['expiresAt'] as String)
          : null,
    );
  }

  /// Convenience: decision is "no, because the user needs to be premium".
  bool get needsPremium =>
      !allowed && (reason == 'premium_required' || reason == 'not_premium');

  /// Convenience: decision is "no, because the resource must be purchased".
  bool get needsPurchase =>
      !allowed && (reason == 'not_purchased' || reason == 'purchase_required');

  @override
  String toString() =>
      'AccessDecision(allowed=$allowed, reason=$reason, grantedBy=$grantedBy)';
}

class AccessService {
  AccessService._();

  // Cache: key = "userId:resourceKey" → (decision, fetchedAt).
  // 60-second TTL keeps the UI snappy while preventing API abuse.
  static final Map<String, _CacheEntry> _cache = {};
  static const Duration _ttl = Duration(seconds: 60);

  static String _userId() {
    final u = FirebaseAuth.instance.currentUser;
    return u?.uid ?? 'anon';
  }

  static String _key(String resource) => '${_userId()}:$resource';

  /// Returns a cached decision if fresh, else null.
  static AccessDecision? _read(String resource) {
    final e = _cache[_key(resource)];
    if (e == null) return null;
    if (DateTime.now().difference(e.fetchedAt) > _ttl) {
      _cache.remove(_key(resource));
      return null;
    }
    return e.decision;
  }

  static void _write(String resource, AccessDecision d) {
    _cache[_key(resource)] = _CacheEntry(decision: d, fetchedAt: DateTime.now());
  }

  /// Clears ALL cached decisions for the current user. Call after a successful
  /// purchase so the next access check reflects the new entitlement.
  static void clearCache() {
    final uid = _userId();
    _cache.removeWhere((k, _) => k.startsWith('$uid:'));
  }

  // ==================== OPTIMISTIC CACHE WRITES ====================
  // After a server-verified successful payment, the backend grants the
  // entitlement in Prisma. Instead of clearing the cache (which forces the
  // NEXT access check to hit the network again — 350-950ms of loading), we
  // write a positive decision directly to the cache. The next access check
  // then returns instantly from the cache (within the 60s TTL).
  //
  // This is safe because:
  //   1. The payment was already server-verified (verifyPayment returned
  //      success+granted=true) before these methods are called.
  //   2. The optimistic local user model is also updated (addPurchasedTest /
  //      markPremium), so local checks agree.
  //   3. The 60s TTL ensures the cache eventually expires and a fresh server
  //      check runs — catching any edge case (refund, expiry, etc.).

  /// Optimistically write a positive "allowed" decision for a test to the
  /// cache. Call this in the Razorpay onSuccess callback AFTER the backend
  /// verify confirms a TEST_PURCHASE was granted.
  static void markTestPurchased(String testId) {
    _write('test:$testId', const AccessDecision(
      allowed: true,
      reason: 'owned',
      grantedBy: 'TEST_PURCHASE',
    ));
  }

  /// Optimistically write a positive "allowed" decision for premium (all
  /// content) to the cache. Call this in the Razorpay onSuccess callback
  /// AFTER the backend verify confirms a PREMIUM_SUBSCRIPTION was granted.
  static void markPremiumGranted() {
    _write('premium:all', const AccessDecision(
      allowed: true,
      reason: 'premium',
      grantedBy: 'PREMIUM_SUBSCRIPTION',
    ));
  }

  /// Optimistically write a positive "allowed" decision for a subject pack
  /// to the cache.
  static void markSubjectPackPurchased(String subjectId) {
    _write('subject:$subjectId', const AccessDecision(
      allowed: true,
      reason: 'owned',
      grantedBy: 'SUBJECT_PACK',
    ));
  }

  /// Optimistically write a positive "allowed" decision for an exam pack
  /// (category) to the cache.
  static void markExamPackPurchased(String categoryId) {
    _write('exam:$categoryId', const AccessDecision(
      allowed: true,
      reason: 'owned',
      grantedBy: 'EXAM_PACK',
    ));
  }

  // ==================== RESOURCE-SPECIFIC CHECKS ====================

  /// Check access to an individual test.
  static Future<AccessDecision> checkTestAccess(
    String testId, {
    String? subjectId,
    String? categoryId,
  }) async {
    final resource = 'test:$testId';
    final cached = _read(resource);
    if (cached != null) return cached;

    try {
      final m = await PaymentApiService.checkAccess(
        type: 'test',
        testId: testId,
        subjectId: subjectId,
        categoryId: categoryId,
      );
      final d = AccessDecision.fromMap(m);
      _write(resource, d);
      return d;
    } on PaymentApiException catch (e) {
      // If the backend isn't ready (404) or network failed, fall back to
      // "denied" with the server's friendly message. The UI will show the
      // paywall, which is the safer default.
      if (e.statusCode == 404) rethrow; // let caller show "rolling out" msg
      return AccessDecision(allowed: false, reason: 'access_check_failed');
    }
  }

  /// Check access to all tests in a subject (subject pack).
  static Future<AccessDecision> checkSubjectAccess(String subjectId) async {
    final resource = 'subject:$subjectId';
    final cached = _read(resource);
    if (cached != null) return cached;

    try {
      final m = await PaymentApiService.checkAccess(
        type: 'subject',
        subjectId: subjectId,
      );
      final d = AccessDecision.fromMap(m);
      _write(resource, d);
      return d;
    } on PaymentApiException catch (e) {
      if (e.statusCode == 404) rethrow;
      return AccessDecision(allowed: false, reason: 'access_check_failed');
    }
  }

  /// Check access to all subjects/tests in a category (exam pack).
  static Future<AccessDecision> checkCategoryAccess(String categoryId) async {
    final resource = 'exam:$categoryId';
    final cached = _read(resource);
    if (cached != null) return cached;

    try {
      final m = await PaymentApiService.checkAccess(
        type: 'exam',
        categoryId: categoryId,
      );
      final d = AccessDecision.fromMap(m);
      _write(resource, d);
      return d;
    } on PaymentApiException catch (e) {
      if (e.statusCode == 404) rethrow;
      return AccessDecision(allowed: false, reason: 'access_check_failed');
    }
  }

  /// Check whether the user is premium (for "all content" gating).
  static Future<AccessDecision> checkPremiumOnly() async {
    const resource = 'premium:all';
    final cached = _read(resource);
    if (cached != null) return cached;

    try {
      final m = await PaymentApiService.checkAccess(type: 'all');
      final d = AccessDecision.fromMap(m);
      _write(resource, d);
      return d;
    } on PaymentApiException catch (e) {
      if (e.statusCode == 404) rethrow;
      return AccessDecision(allowed: false, reason: 'access_check_failed');
    }
  }
}

class _CacheEntry {
  final AccessDecision decision;
  final DateTime fetchedAt;
  const _CacheEntry({required this.decision, required this.fetchedAt});
}
