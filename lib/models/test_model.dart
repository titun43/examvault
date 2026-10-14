// =============================================================================
// ExamVault - Test Model (Mock Test)
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

enum TestType { mock, previousYear, dailyQuiz, practice, subjectwise }
enum TestDifficulty { easy, medium, hard }

class TestModel {
  final String id;
  final String subjectId;
  final String title;
  final String slug;
  // Bilingual Assamese content fields. Note: the English `description` is not
  // modeled here yet (admin may still write `descriptionAs` to Firestore for
  // future expansion); `titleAs` and `instructionsAs` mirror existing English
  // fields. Resolved at display time via localized_content.dart.
  final String? titleAs;
  final String? descriptionAs;
  final String? instructionsAs;
  final TestType type;
  final int duration; // minutes
  final int totalMarks;
  final int passingMarks;
  final bool isPublished;
  final TestDifficulty difficulty;
  final bool negativeMarking;
  final double negativeMarks;
  final String? instructions;
  final int? year;
  final String? examSession;
  final bool isPremium;
  final int price; // Per-test price in INR (0 = free)
  final int questionCount;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  TestModel({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.slug,
    this.titleAs,
    this.descriptionAs,
    this.instructionsAs,
    this.type = TestType.mock,
    required this.duration,
    required this.totalMarks,
    required this.passingMarks,
    this.isPublished = true,
    this.difficulty = TestDifficulty.medium,
    this.negativeMarking = false,
    this.negativeMarks = 0.25,
    this.instructions,
    this.year,
    this.examSession,
    this.isPremium = false,
    this.price = 0,
    this.questionCount = 0,
    this.attemptCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether this test requires payment (either per-test or via premium).
  bool get isPaid => price > 0 || isPremium;

  factory TestModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic raw = doc.data();
    if (raw == null) {
      return TestModel(
        id: doc.id,
        subjectId: '',
        title: '',
        slug: '',
        duration: 60,
        totalMarks: 100,
        passingMarks: 40,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    return TestModel(
      id: doc.id,
      subjectId: (data['subjectId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      slug: (data['slug'] ?? '').toString(),
      titleAs: data['titleAs']?.toString(),
      descriptionAs: data['descriptionAs']?.toString(),
      instructionsAs: data['instructionsAs']?.toString(),
      type: _parseTestType(data['type']?.toString()),
      duration: _toInt(data['duration'], 60),
      totalMarks: _toInt(data['totalMarks'], 100),
      passingMarks: _toInt(data['passingMarks'], 40),
      isPublished: data['isPublished'] ?? true,
      difficulty: _parseDifficulty(data['difficulty']?.toString()),
      negativeMarking: data['negativeMarking'] ?? false,
      negativeMarks: _toDouble(data['negativeMarks'], 0.25),
      instructions: data['instructions']?.toString(),
      year: data['year'] is int ? data['year'] : null,
      examSession: data['examSession']?.toString(),
      isPremium: data['isPremium'] ?? false,
      price: _toInt(data['price'], 0),
      questionCount: _toInt(data['questionCount'], 0),
      attemptCount: _toInt(data['attemptCount'], 0),
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

  static double _toDouble(dynamic v, double fallback) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'subjectId': subjectId,
      'title': title,
      'slug': slug,
      'titleAs': titleAs,
      'descriptionAs': descriptionAs,
      'instructionsAs': instructionsAs,
      'type': type.name,
      'duration': duration,
      'totalMarks': totalMarks,
      'passingMarks': passingMarks,
      'isPublished': isPublished,
      'difficulty': difficulty.name,
      'negativeMarking': negativeMarking,
      'negativeMarks': negativeMarks,
      'instructions': instructions,
      'year': year,
      'examSession': examSession,
      'isPremium': isPremium,
      'price': price,
      'questionCount': questionCount,
      'attemptCount': attemptCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static TestType _parseTestType(String? type) {
    switch (type) {
      case 'previousYear': return TestType.previousYear;
      case 'dailyQuiz': return TestType.dailyQuiz;
      case 'practice': return TestType.practice;
      case 'subjectwise': return TestType.subjectwise;
      default: return TestType.mock;
    }
  }

  static TestDifficulty _parseDifficulty(String? difficulty) {
    switch (difficulty) {
      case 'easy': return TestDifficulty.easy;
      case 'hard': return TestDifficulty.hard;
      default: return TestDifficulty.medium;
    }
  }

  TestModel copyWith({
    String? subjectId,
    String? title,
    String? slug,
    String? titleAs,
    String? descriptionAs,
    String? instructionsAs,
    TestType? type,
    int? duration,
    int? totalMarks,
    int? passingMarks,
    bool? isPublished,
    TestDifficulty? difficulty,
    bool? negativeMarking,
    double? negativeMarks,
    String? instructions,
    int? year,
    String? examSession,
    bool? isPremium,
    int? price,
    int? questionCount,
    int? attemptCount,
    DateTime? updatedAt,
  }) {
    return TestModel(
      id: id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      titleAs: titleAs ?? this.titleAs,
      descriptionAs: descriptionAs ?? this.descriptionAs,
      instructionsAs: instructionsAs ?? this.instructionsAs,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      totalMarks: totalMarks ?? this.totalMarks,
      passingMarks: passingMarks ?? this.passingMarks,
      isPublished: isPublished ?? this.isPublished,
      difficulty: difficulty ?? this.difficulty,
      negativeMarking: negativeMarking ?? this.negativeMarking,
      negativeMarks: negativeMarks ?? this.negativeMarks,
      instructions: instructions ?? this.instructions,
      year: year ?? this.year,
      examSession: examSession ?? this.examSession,
      isPremium: isPremium ?? this.isPremium,
      price: price ?? this.price,
      questionCount: questionCount ?? this.questionCount,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
