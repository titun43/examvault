// =============================================================================
// ExamVault - Category Model (Exam Categories: Railway, SSC, UPSC, etc.)
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;
  final String slug;
  final String? icon;
  final String? description;
  final String? image;
  final String? color;
  final int order;
  final int subjectCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.description,
    this.image,
    this.color,
    this.order = 0,
    this.subjectCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      slug: data['slug'] ?? '',
      icon: data['icon'],
      description: data['description'],
      image: data['image'],
      color: data['color'],
      order: data['order'] ?? 0,
      subjectCount: data['subjectCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'slug': slug,
      'icon': icon,
      'description': description,
      'image': image,
      'color': color,
      'order': order,
      'subjectCount': subjectCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CategoryModel copyWith({
    String? name,
    String? slug,
    String? icon,
    String? description,
    String? image,
    String? color,
    int? order,
    int? subjectCount,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      image: image ?? this.image,
      color: color ?? this.color,
      order: order ?? this.order,
      subjectCount: subjectCount ?? this.subjectCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
