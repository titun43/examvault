// =============================================================================
// ExamVault - Category Model (Exam Categories: Railway, SSC, UPSC, etc.)
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

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
  // Premium-category fields (set by admin). When isPremium is true, the
  // category is locked behind a subscription. premiumPrice is the displayed
  // price (INR); premiumDurationMonths is the subscription duration.
  final bool isPremium;
  final int premiumPrice;
  final int premiumDurationMonths;
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
    this.isPremium = false,
    this.premiumPrice = 0,
    this.premiumDurationMonths = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic raw = doc.data();
    if (raw == null) {
      return CategoryModel(
        id: doc.id,
        name: '',
        slug: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    return CategoryModel(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      slug: (data['slug'] ?? '').toString(),
      icon: data['icon']?.toString(),
      description: data['description']?.toString(),
      image: data['image']?.toString(),
      color: data['color']?.toString(),
      order: _toInt(data['order'], 0),
      subjectCount: _toInt(data['subjectCount'], 0),
      isPremium: data['isPremium'] ?? false,
      premiumPrice: _toInt(data['premiumPrice'], 0),
      premiumDurationMonths: _toInt(data['premiumDurationMonths'], 0),
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
      'name': name,
      'slug': slug,
      'icon': icon,
      'description': description,
      'image': image,
      'color': color,
      'order': order,
      'subjectCount': subjectCount,
      'isPremium': isPremium,
      'premiumPrice': premiumPrice,
      'premiumDurationMonths': premiumDurationMonths,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Convenience factory used as `orElse` sentinel in `firstWhere` calls that
  /// look up a category by subject.categoryId. Always check `.id.isNotEmpty`
  /// before using the result — an empty-id model means "no match found".
  factory CategoryModel.empty() => CategoryModel(
        id: '',
        name: '',
        slug: '',
        createdAt: DateTime(0),
        updatedAt: DateTime(0),
      );

  CategoryModel copyWith({
    String? name,
    String? slug,
    String? icon,
    String? description,
    String? image,
    String? color,
    int? order,
    int? subjectCount,
    bool? isPremium,
    int? premiumPrice,
    int? premiumDurationMonths,
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
      isPremium: isPremium ?? this.isPremium,
      premiumPrice: premiumPrice ?? this.premiumPrice,
      premiumDurationMonths: premiumDurationMonths ?? this.premiumDurationMonths,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
