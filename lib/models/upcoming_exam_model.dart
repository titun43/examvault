// =============================================================================
// ExamVault - Upcoming Exam Model
// Admin-curated list of upcoming government / competitive exams shown to users.
// Optional URL fields: notificationUrl (PDF), syllabusUrl, officialUrl (the
// exam's official website/page), applyUrl (direct application/registration URL).
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

class UpcomingExamModel {
  final String id;
  final String name;
  final String? organization;       // e.g. "RRB", "SSC", "UPSC"
  // Bilingual Assamese content fields (admin writes these alongside the
  // English fields; resolved at display time via localized_content.dart).
  final String? nameAs;
  final String? organizationAs;
  final String? descriptionAs;
  final String? categoryId;         // links to a Category (optional)
  final DateTime examDate;          // actual exam date
  final DateTime? applicationStartDate;
  final DateTime? applicationEndDate;
  final String? notificationUrl;    // link to official notification PDF
  final String? syllabusUrl;
  final String? officialUrl;        // link to the exam's official website/page
  final String? applyUrl;           // direct application / registration URL
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
    this.nameAs,
    this.organizationAs,
    this.descriptionAs,
    this.categoryId,
    required this.examDate,
    this.applicationStartDate,
    this.applicationEndDate,
    this.notificationUrl,
    this.syllabusUrl,
    this.officialUrl,
    this.applyUrl,
    this.imageUrl,
    this.description = '',
    this.tags = const [],
    this.isPublished = true,
    this.order = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UpcomingExamModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic raw = doc.data();
    if (raw == null) {
      return UpcomingExamModel(
        id: doc.id,
        name: '',
        examDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    return UpcomingExamModel(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      organization: data['organization']?.toString(),
      nameAs: data['nameAs']?.toString(),
      organizationAs: data['organizationAs']?.toString(),
      descriptionAs: data['descriptionAs']?.toString(),
      categoryId: data['categoryId']?.toString(),
      examDate: parseTimestamp(data['examDate']),
      applicationStartDate: parseTimestampNullable(data['applicationStartDate']),
      applicationEndDate: parseTimestampNullable(data['applicationEndDate']),
      notificationUrl: data['notificationUrl']?.toString(),
      syllabusUrl: data['syllabusUrl']?.toString(),
      officialUrl: data['officialUrl']?.toString(),
      applyUrl: data['applyUrl']?.toString(),
      imageUrl: data['imageUrl']?.toString(),
      description: (data['description'] ?? '').toString(),
      tags: data['tags'] is List
          ? List<String>.from(
              (data['tags'] as List).map((e) => e.toString()))
          : const [],
      isPublished: data['isPublished'] ?? true,
      order: _toInt(data['order'], 0),
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
      'organization': organization,
      'nameAs': nameAs,
      'organizationAs': organizationAs,
      'descriptionAs': descriptionAs,
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
      'officialUrl': officialUrl,
      'applyUrl': applyUrl,
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
