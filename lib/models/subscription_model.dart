// =============================================================================
// ExamVault - Subscription Model
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionPlan { monthly, quarterly, yearly }

class SubscriptionModel {
  final String id;
  final String userId;
  final SubscriptionPlan plan;
  final int amount; // in paise
  final String paymentId;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime createdAt;

  SubscriptionModel({
    required this.id,
    required this.userId,
    required this.plan,
    required this.amount,
    required this.paymentId,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    required this.createdAt,
  });

  factory SubscriptionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubscriptionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      plan: _parsePlan(data['plan']),
      amount: data['amount'] ?? 0,
      paymentId: data['paymentId'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'plan': plan.name,
      'amount': amount,
      'paymentId': paymentId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static SubscriptionPlan _parsePlan(String? plan) {
    switch (plan) {
      case 'monthly': return SubscriptionPlan.monthly;
      case 'quarterly': return SubscriptionPlan.quarterly;
      case 'yearly': return SubscriptionPlan.yearly;
      default: return SubscriptionPlan.monthly;
    }
  }

  int get durationMonths {
    switch (plan) {
      case SubscriptionPlan.monthly: return 1;
      case SubscriptionPlan.quarterly: return 3;
      case SubscriptionPlan.yearly: return 12;
    }
  }
}
