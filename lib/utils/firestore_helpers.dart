// =============================================================================
// ExamVault - Firestore Helpers
// Null-safe parsing utilities that prevent a single bad document from killing
// an entire stream. The admin web panel writes timestamps using Firebase's
// serverTimestamp(), which is briefly `null` on the client until the server
// resolves it. Previously the models did `(data['createdAt'] as Timestamp)`
// which threw a TypeError during that window — and because that throw happens
// inside a stream's `.map()`, the whole stream errors out and the user sees
// nothing. These helpers gracefully fall back instead.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

/// Parses a Firestore value into a [DateTime].
///
/// Handles:
///  - Firestore [Timestamp] (the normal case)
///  - `null` / missing field → returns [fallback] (default: now)
///  - `int` milliseconds-since-epoch (defensive; some legacy imports)
///  - `String` ISO-8601 (defensive)
///
/// NEVER throws.
DateTime parseTimestamp(dynamic value, {DateTime? fallback}) {
  final fb = fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  if (value == null) return fb;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return fb;
    }
  }
  return fb;
}

/// Parses an optional Firestore timestamp. Returns `null` when the value is
/// null/missing. NEVER throws.
DateTime? parseTimestampNullable(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}
