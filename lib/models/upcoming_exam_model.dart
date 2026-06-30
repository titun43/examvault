// =============================================================================
// ExamVault - Upcoming Exam Model
// Admin-curated list of upcoming government / competitive exams shown to users.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class UpcomingExamModel {
  final String id;
  final String name;
  final String? organization;       // e.g. "RRB", "SSC", "UPSC"
  final String? categoryId;         // links to a Category (optional)
  final DateTime examDate;          // actual exam date
  final DateTime? applicationStartDate;
  final DateTime? applicationEndDate;
  final String? notificationUrl;    // link to official notification PDF
  final String? syllabusUrl;
  final String? imageUrl;
  final String description;
  final List<String> tags;
  final bool isPublished;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  UpcomingExamModel({
    required this.id,
    required this.name,
    this.organization,
    this.categoryId,
    required this.examDate,
    this.applicationStartDate,
    this.applicationEndDate,
    this.notificationUrl,
    this.syllabusUrl,
    this.imageUrl,
    this.description = '',
    this.tags = const [],
    this.isPublished = true,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UpcomingExamModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UpcomingExamModel(
      id: doc.id,
      name: data['name'] ?? '',
      organization: data['organization'],
      categoryId: data['categoryId'],
      examDate: (data['examDate'] as Timestamp).toDate(),
      applicationStartDate: (data['applicationStartDate'] as Timestamp?)?.toDate(),
      applicationEndDate: (data['applicationEndDate'] as Timestamp?)?.toDate(),
      notificationUrl: data['notificationUrl'],
      syllabusUrl: data['syllabusUrl'],
      imageUrl: data['imageUrl'],
      description: data['description'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      isPublished: data['isPublished'] ?? true,
      order: data['order'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'organization': organization,
      'categoryId': categoryId,
      'examDate': Timestamp.fromDate(examDate),
      'applicationStartDate': applicationStartDate != null
          ? Timestamp.fromDate(applicationStartDate!)
          : null,
      'applicationEndDate': applicationEndDate != null
          ? Timestamp.fromDate(applicationEndDate!)
          : null,
      'notificationUrl': notificationUrl,
      'syllabusUrl': syllabusUrl,
      'imageUrl': imageUrl,
      'description': description,
      'tags': tags,
      'isPublished': isPublished,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Days remaining until exam (negative if exam is in the past).
  int get daysRemaining => examDate.difference(DateTime.now()).inDays;

  /// True if the application window is currently open.
  bool get applicationOpen {
    final now = DateTime.now();
    final start = applicationStartDate;
    final end = applicationEndDate;
    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(end)) return false;
    return true;
  }
}
