// =============================================================================
// ExamVault - Current Affairs Model
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

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
    final data = doc.data() as Map<String, dynamic>;
    return CurrentAffairModel(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      summary: data['summary'] ?? '',
      pdfUrl: data['pdfUrl'],
      imageUrl: data['imageUrl'],
      source: data['source'] ?? '',
      category: data['category'] ?? '',
      categoryId: data['categoryId'],
      isImportant: data['isImportant'] ?? false,
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
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
