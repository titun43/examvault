// =============================================================================
// ExamVault - Premium Plan Model
// Admin-controllable premium subscription plans. Stored in the
// `premium_plans` Firestore collection. The premium screen fetches these and
// falls back to the hardcoded AppConfig defaults if the collection is empty
// or errors out — so the screen always works.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

class PremiumPlanModel {
  final String id;
  final String name;
  final int price; // INR
  final int durationMonths;
  final String durationLabel; // e.g. "1 Month", "3 Months"
  final String planId; // Razorpay plan id
  final String? description;
  final List<String> features;
  final bool isPopular;
  final bool isActive;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  PremiumPlanModel({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMonths,
    required this.durationLabel,
    required this.planId,
    this.description,
    this.features = const [],
    this.isPopular = false,
    this.isActive = true,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PremiumPlanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PremiumPlanModel(
      id: doc.id,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toInt(),
      durationMonths: (data['durationMonths'] ?? 1).toInt(),
      durationLabel: data['durationLabel'] ?? '',
      planId: data['planId'] ?? '',
      description: data['description'],
      features: List<String>.from(data['features'] ?? []),
      isPopular: data['isPopular'] ?? false,
      isActive: data['isActive'] ?? true,
      order: (data['order'] ?? 0).toInt(),
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'durationMonths': durationMonths,
      'durationLabel': durationLabel,
      'planId': planId,
      'description': description,
      'features': features,
      'isPopular': isPopular,
      'isActive': isActive,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PremiumPlanModel copyWith({
    String? name,
    int? price,
    int? durationMonths,
    String? durationLabel,
    String? planId,
    String? description,
    List<String>? features,
    bool? isPopular,
    bool? isActive,
    int? order,
    DateTime? updatedAt,
  }) {
    return PremiumPlanModel(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      durationMonths: durationMonths ?? this.durationMonths,
      durationLabel: durationLabel ?? this.durationLabel,
      planId: planId ?? this.planId,
      description: description ?? this.description,
      features: features ?? this.features,
      isPopular: isPopular ?? this.isPopular,
      isActive: isActive ?? this.isActive,
      order: order ?? this.order,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
