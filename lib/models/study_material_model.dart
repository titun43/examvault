// =============================================================================
// ExamVault - Study Material Model
// =============================================================================
// Admin-managed PDF content that appears on the Subject Detail screen.
//
// Types:
//   previousPaper — Previous Year Papers (actual exam question paper PDFs)
//   notes         — Study Notes (theory / chapter notes PDFs)
//   syllabus      — Syllabus PDFs
//
// The Flutter app subscribes to a real-time stream of these docs filtered by
// subjectId. For each `type`, it counts how many published materials exist
// and shows a content-type card ONLY if count > 0. This means:
//   - Admin hasn't added any materials → no cards shown (clean UI)
//   - Admin adds a Previous Year Paper → the "📄 Previous Papers" card
//     appears automatically on the user's Subject Detail screen
//   - Admin deletes the last material of a type → the card disappears
//
// This mirrors the real-time pattern used by tests/announcements/etc.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

/// The type of study material. Determines the icon, color, and label shown
/// in the UI. Stored as a plain string in Firestore for cross-platform
/// compatibility (the admin panel writes the same string values).
enum StudyMaterialType {
  previousPaper,
  notes,
  syllabus;

  /// Parses a Firestore string into the enum. Unknown / null values default
  /// to [notes] so a typo in the admin panel never crashes the user app.
  static StudyMaterialType fromString(String? value) {
    switch (value) {
      case 'previousPaper':
        return StudyMaterialType.previousPaper;
      case 'syllabus':
        return StudyMaterialType.syllabus;
      case 'notes':
      default:
        return StudyMaterialType.notes;
    }
  }

  /// The string stored in Firestore. The admin panel must use the same values.
  String get value {
    switch (this) {
      case StudyMaterialType.previousPaper:
        return 'previousPaper';
      case StudyMaterialType.notes:
        return 'notes';
      case StudyMaterialType.syllabus:
        return 'syllabus';
    }
  }

  /// Human-readable label shown on cards and list screens.
  String get label {
    switch (this) {
      case StudyMaterialType.previousPaper:
        return 'Previous Papers';
      case StudyMaterialType.notes:
        return 'Study Notes';
      case StudyMaterialType.syllabus:
        return 'Syllabus';
    }
  }

  /// Emoji icon used in the content-type grid card.
  String get emoji {
    switch (this) {
      case StudyMaterialType.previousPaper:
        return '📄';
      case StudyMaterialType.notes:
        return '📖';
      case StudyMaterialType.syllabus:
        return '📋';
    }
  }

  /// Short singular label (e.g. "Paper", "Note") used in the list screen
  /// title: "3 Papers in History".
  String get singularLabel {
    switch (this) {
      case StudyMaterialType.previousPaper:
        return 'Paper';
      case StudyMaterialType.notes:
        return 'Note';
      case StudyMaterialType.syllabus:
        return 'Syllabus';
    }
  }

  /// Plural label (e.g. "Papers", "Notes").
  String get pluralLabel {
    switch (this) {
      case StudyMaterialType.previousPaper:
        return 'Papers';
      case StudyMaterialType.notes:
        return 'Notes';
      case StudyMaterialType.syllabus:
        return 'Syllabi';
    }
  }
}

class StudyMaterialModel {
  final String id;
  final String subjectId;
  final String categoryId;
  final StudyMaterialType type;
  final String title;
  final String? description;
  final String pdfUrl;
  final String? thumbnailUrl;
  final int? year;
  final int? pages;
  final bool isPremium;
  final bool isPublished;
  final int order;
  final int downloadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyMaterialModel({
    required this.id,
    required this.subjectId,
    required this.categoryId,
    required this.type,
    required this.title,
    this.description,
    required this.pdfUrl,
    this.thumbnailUrl,
    this.year,
    this.pages,
    this.isPremium = false,
    this.isPublished = true,
    this.order = 0,
    this.downloadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyMaterialModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic raw = doc.data();
    if (raw == null) {
      return StudyMaterialModel(
        id: doc.id,
        subjectId: '',
        categoryId: '',
        type: StudyMaterialType.notes,
        title: '',
        pdfUrl: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    return StudyMaterialModel(
      id: doc.id,
      subjectId: (data['subjectId'] ?? '').toString(),
      categoryId: (data['categoryId'] ?? '').toString(),
      type: StudyMaterialType.fromString(data['type']?.toString()),
      title: (data['title'] ?? '').toString(),
      description: data['description']?.toString(),
      pdfUrl: (data['pdfUrl'] ?? '').toString(),
      thumbnailUrl: data['thumbnailUrl']?.toString(),
      year: data['year'] != null ? _toInt(data['year']) : null,
      pages: data['pages'] != null ? _toInt(data['pages']) : null,
      isPremium: data['isPremium'] == true,
      isPublished: data['isPublished'] != false, // default true if missing
      order: _toInt(data['order'], 0),
      downloadCount: _toInt(data['downloadCount'], 0),
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  static int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subjectId': subjectId,
      'categoryId': categoryId,
      'type': type.value,
      'title': title,
      'description': description,
      'pdfUrl': pdfUrl,
      'thumbnailUrl': thumbnailUrl,
      'year': year,
      'pages': pages,
      'isPremium': isPremium,
      'isPublished': isPublished,
      'order': order,
      'downloadCount': downloadCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
