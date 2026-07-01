// =============================================================================
// ExamVault - Subject Model (e.g., General Knowledge, Math, etc.)
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

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
    final dynamic raw = doc.data();
    if (raw == null) {
      return SubjectModel(
        id: doc.id,
        categoryId: '',
        name: '',
        slug: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    return SubjectModel(
      id: doc.id,
      categoryId: (data['categoryId'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      slug: (data['slug'] ?? '').toString(),
      icon: data['icon']?.toString(),
      description: data['description']?.toString(),
      order: _toInt(data['order'], 0),
      testCount: _toInt(data['testCount'], 0),
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  static int _toInt(dynamic v, int fallback) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
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
