// =============================================================================
// ExamVault - Admin Model
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

enum AdminRole { superAdmin, contentManager, financeManager, support }

class AdminModel {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final AdminRole role;
  final bool isActive;
  final DateTime lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  AdminModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.role = AdminRole.contentManager,
    this.isActive = true,
    required this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'],
      role: _parseRole(data['role']),
      isActive: data['isActive'] ?? true,
      lastLoginAt: parseTimestampNullable(data['lastLoginAt']) ?? DateTime.now(),
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role.name,
      'isActive': isActive,
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static AdminRole _parseRole(String? role) {
    switch (role) {
      case 'superAdmin': return AdminRole.superAdmin;
      case 'financeManager': return AdminRole.financeManager;
      case 'support': return AdminRole.support;
      default: return AdminRole.contentManager;
    }
  }
}
