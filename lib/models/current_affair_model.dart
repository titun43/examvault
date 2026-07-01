// =============================================================================
// ExamVault - Current Affairs Model
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

class CurrentAffairModel {
  final String id;
  final DateTime date;
  final String title;
  final String content;
  final String summary;
  final String? pdfUrl;
  final String? imageUrl;
  final String source;
  final String category;
  final String? categoryId;
  final bool isImportant;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  CurrentAffairModel({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    required this.summary,
    this.pdfUrl,
    this.imageUrl,
    this.source = '',
    this.category = '',
    this.categoryId,
    this.isImportant = false,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory CurrentAffairModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic raw = doc.data();
    if (raw == null) {
      return CurrentAffairModel(
        id: doc.id,
        date: DateTime.now(),
        title: '',
        content: '',
        summary: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    return CurrentAffairModel(
      id: doc.id,
      date: parseTimestamp(data['date']),
      title: (data['title'] ?? '').toString(),
      content: (data['content'] ?? '').toString(),
      summary: (data['summary'] ?? '').toString(),
      pdfUrl: data['pdfUrl']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      source: (data['source'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      categoryId: data['categoryId']?.toString(),
      isImportant: data['isImportant'] ?? false,
      tags: data['tags'] is List
          ? List<String>.from(
              (data['tags'] as List).map((e) => e.toString()))
          : const [],
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'title': title,
      'content': content,
      'summary': summary,
      'pdfUrl': pdfUrl,
      'imageUrl': imageUrl,
      'source': source,
      'category': category,
      'categoryId': categoryId,
      'isImportant': isImportant,
      'tags': tags,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
