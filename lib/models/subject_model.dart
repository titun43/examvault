// =============================================================================
// ExamVault - Subject Model (e.g., General Knowledge, Math, etc.)
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectModel {
  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final String? icon;
  final String? description;
  final int order;
  final int testCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubjectModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    this.icon,
    this.description,
    this.order = 0,
    this.testCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SubjectModel(
      id: doc.id,
      categoryId: data['categoryId'] ?? '',
      name: data['name'] ?? '',
      slug: data['slug'] ?? '',
      icon: data['icon'],
      description: data['description'],
      order: data['order'] ?? 0,
      testCount: data['testCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'categoryId': categoryId,
      'name': name,
      'slug': slug,
      'icon': icon,
      'description': description,
      'order': order,
      'testCount': testCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SubjectModel copyWith({
    String? categoryId,
    String? name,
    String? slug,
    String? icon,
    String? description,
    int? order,
    int? testCount,
    DateTime? updatedAt,
  }) {
    return SubjectModel(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      order: order ?? this.order,
      testCount: testCount ?? this.testCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
