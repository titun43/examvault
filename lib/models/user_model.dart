// =============================================================================
// ExamVault - User Model
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

enum UserRole { user, admin }

enum SubscriptionStatus { free, premium, expired }

class UserModel {
  final String id;
  final String name;
  final String? email;
  final String? phoneNumber;
  final String? photoUrl;
  final UserRole role;
  final SubscriptionStatus subscriptionStatus;
  final DateTime? subscriptionExpiry;
  final String? subscriptionPlanId;
  final int totalTestsAttempted;
  final double averageScore;
  final int totalXp;
  final int level;
  final int streak;
  final DateTime? lastActiveAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? fcmToken;
  final Map<String, dynamic> preferences;
  final List<String> purchasedTests; // test IDs the user has bought (pay-per-test)
  final List<String> purchasedCategoryIds; // category IDs unlocked via exam-pack purchase

  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phoneNumber,
    this.photoUrl,
    this.role = UserRole.user,
    this.subscriptionStatus = SubscriptionStatus.free,
    this.subscriptionExpiry,
    this.subscriptionPlanId,
    this.totalTestsAttempted = 0,
    this.averageScore = 0,
    this.totalXp = 0,
    this.level = 1,
    this.streak = 0,
    this.lastActiveAt,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.fcmToken,
    this.preferences = const {},
    this.purchasedTests = const [],
    this.purchasedCategoryIds = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic raw = doc.data();
    if (raw == null) {
      // Doc has no data — return a minimal user so the caller doesn't crash.
      // This can happen for a freshly-created doc that hasn't been written yet.
      return UserModel(
        id: doc.id,
        name: 'User',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    return UserModel(
      id: doc.id,
      name: (data['name'] ?? 'User').toString(),
      email: data['email']?.toString(),
      phoneNumber: data['phoneNumber']?.toString(),
      photoUrl: data['photoUrl']?.toString(),
      role: data['role'] == 'admin' ? UserRole.admin : UserRole.user,
      subscriptionStatus: _parseSubscriptionStatus(
          data['subscriptionStatus']?.toString()),
      subscriptionExpiry: parseTimestampNullable(data['subscriptionExpiry']),
      subscriptionPlanId: data['subscriptionPlanId']?.toString(),
      // Numeric fields: be defensive — Firestore might store them as int,
      // double, num, or even String (manual console edit). Parse safely.
      totalTestsAttempted: _toInt(data['totalTestsAttempted'], 0),
      averageScore: _toDouble(data['averageScore'], 0),
      totalXp: _toInt(data['totalXp'], 0),
      level: _toInt(data['level'], 1),
      streak: _toInt(data['streak'], 0),
      lastActiveAt: parseTimestampNullable(data['lastActiveAt']),
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
      isActive: data['isActive'] ?? true,
      fcmToken: data['fcmToken']?.toString(),
      preferences: data['preferences'] is Map
          ? Map<String, dynamic>.from(data['preferences'] as Map)
          : const {},
      purchasedTests: data['purchasedTests'] is List
          ? List<String>.from(
              (data['purchasedTests'] as List).map((e) => e.toString()))
          : const [],
      purchasedCategoryIds: data['purchasedCategoryIds'] is List
          ? List<String>.from(
              (data['purchasedCategoryIds'] as List).map((e) => e.toString()))
          : const [],
    );
  }

  /// Safely converts a dynamic value to int. Handles int, double, num, String,
  /// and null. NEVER throws.
  static int _toInt(dynamic v, int fallback) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  /// Safely converts a dynamic value to double. NEVER throws.
  static double _toDouble(dynamic v, double fallback) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'role': role == UserRole.admin ? 'admin' : 'user',
      'isPremium': isPremium, // denormalized boolean for easy Firestore/Storage rule checks
      'subscriptionStatus': subscriptionStatus.name,
      'subscriptionExpiry': subscriptionExpiry != null
          ? Timestamp.fromDate(subscriptionExpiry!)
          : null,
      'subscriptionPlanId': subscriptionPlanId,
      'totalTestsAttempted': totalTestsAttempted,
      'averageScore': averageScore,
      'totalXp': totalXp,
      'level': level,
      'streak': streak,
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'fcmToken': fcmToken,
      'preferences': preferences,
      'purchasedTests': purchasedTests,
      'purchasedCategoryIds': purchasedCategoryIds,
    };
  }

  bool get isPremium =>
      subscriptionStatus == SubscriptionStatus.premium &&
      (subscriptionExpiry == null || subscriptionExpiry!.isAfter(DateTime.now()));

  /// Whether the user has bought a specific test (pay-per-test) OR is premium
  /// (premium users get all tests unlocked).
  bool hasTestAccess(String testId) =>
      isPremium || purchasedTests.contains(testId);

  /// Whether the user can open a premium category RIGHT NOW —
  /// either via premium subscription or an exam-pack purchase.
  bool hasCategoryAccess(String categoryId) =>
      isPremium || purchasedCategoryIds.contains(categoryId);

  bool get isAdmin => role == UserRole.admin;

  // ==================== PREFERENCE CONVENIENCE GETTERS ====================
  // The `preferences` map holds optional profile fields set from the
  // EditProfileScreen (DOB, gender, qualification, etc.). These getters give
  // typed access so screens don't need to remember the string keys.

  /// Date of birth stored as a Firestore Timestamp in preferences['dateOfBirth'].
  DateTime? get dateOfBirth {
    final v = preferences['dateOfBirth'];
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String? get gender => preferences['gender'] as String?;

  String? get qualification => preferences['qualification'] as String?;

  String? get city => preferences['city'] as String?;

  String? get targetExam => preferences['targetExam'] as String?;

  static SubscriptionStatus _parseSubscriptionStatus(String? status) {
    switch (status) {
      case 'premium':
        return SubscriptionStatus.premium;
      case 'expired':
        return SubscriptionStatus.expired;
      default:
        return SubscriptionStatus.free;
    }
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    UserRole? role,
    SubscriptionStatus? subscriptionStatus,
    DateTime? subscriptionExpiry,
    String? subscriptionPlanId,
    int? totalTestsAttempted,
    double? averageScore,
    int? totalXp,
    int? level,
    int? streak,
    DateTime? lastActiveAt,
    DateTime? updatedAt,
    bool? isActive,
    String? fcmToken,
    Map<String, dynamic>? preferences,
    List<String>? purchasedTests,
    List<String>? purchasedCategoryIds,
    // Individual preference overrides — these are merged into the preferences
    // map on top of any `preferences` value passed above. `null` means "leave
    // unchanged" (use [clearPreference] semantics by setting an explicit
    // removal in [preferences] if you need to wipe one).
    DateTime? dateOfBirth,
    String? gender,
    String? qualification,
    String? city,
    String? targetExam,
  }) {
    // Build the merged preferences map. Start from the existing one, layer on
    // the explicit `preferences` arg, then apply individual overrides.
    final merged = Map<String, dynamic>.from(this.preferences);
    if (preferences != null) {
      merged.addAll(preferences);
    }
    if (dateOfBirth != null) {
      merged['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
    }
    if (gender != null) merged['gender'] = gender;
    if (qualification != null) merged['qualification'] = qualification;
    if (city != null) merged['city'] = city;
    if (targetExam != null) merged['targetExam'] = targetExam;

    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      subscriptionPlanId: subscriptionPlanId ?? this.subscriptionPlanId,
      totalTestsAttempted: totalTestsAttempted ?? this.totalTestsAttempted,
      averageScore: averageScore ?? this.averageScore,
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
      streak: streak ?? this.streak,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      fcmToken: fcmToken ?? this.fcmToken,
      preferences: merged,
      purchasedTests: purchasedTests ?? this.purchasedTests,
      purchasedCategoryIds: purchasedCategoryIds ?? this.purchasedCategoryIds,
    );
  }
}
