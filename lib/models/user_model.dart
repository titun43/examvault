// =============================================================================
// ExamVault - User Model
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      photoUrl: data['photoUrl'],
      role: data['role'] == 'admin' ? UserRole.admin : UserRole.user,
      subscriptionStatus: _parseSubscriptionStatus(data['subscriptionStatus']),
      subscriptionExpiry: (data['subscriptionExpiry'] as Timestamp?)?.toDate(),
      subscriptionPlanId: data['subscriptionPlanId'],
      totalTestsAttempted: data['totalTestsAttempted'] ?? 0,
      averageScore: (data['averageScore'] ?? 0).toDouble(),
      totalXp: data['totalXp'] ?? 0,
      level: data['level'] ?? 1,
      streak: data['streak'] ?? 0,
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      fcmToken: data['fcmToken'],
      preferences: data['preferences'] ?? {},
    );
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
    };
  }

  bool get isPremium =>
      subscriptionStatus == SubscriptionStatus.premium &&
      (subscriptionExpiry == null || subscriptionExpiry!.isAfter(DateTime.now()));

  bool get isAdmin => role == UserRole.admin;

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
  }) {
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
      preferences: preferences ?? this.preferences,
    );
  }
}
