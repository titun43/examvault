// =============================================================================
// ExamVault - Question Model
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

class QuestionModel {
  final String id;
  final String testId;
  final String question;
  // Bilingual Assamese content fields. `questionAs`/`explanationAs` are
  // nullable strings; `optionsAs` is a list (kept parallel to `options` but
  // defensively length-checked at display time via localized_content.dart).
  final String? questionAs;
  final List<String> optionsAs;
  final String? explanationAs;
  final List<String> options;
  final int correctAnswerIndex;
  final String? explanation;
  final String? subjectTopic;
  final int marks;
  final bool isPremium;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuestionModel({
    required this.id,
    required this.testId,
    required this.question,
    required this.options,
    this.questionAs,
    this.optionsAs = const [],
    this.explanationAs,
    required this.correctAnswerIndex,
    this.explanation,
    this.subjectTopic,
    this.marks = 1,
    this.isPremium = false,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QuestionModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic raw = doc.data();
    if (raw == null) {
      return QuestionModel(
        id: doc.id,
        testId: '',
        question: '',
        options: const [],
        correctAnswerIndex: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    return QuestionModel(
      id: doc.id,
      testId: (data['testId'] ?? '').toString(),
      question: (data['question'] ?? '').toString(),
      questionAs: data['questionAs']?.toString(),
      options: data['options'] is List
          ? List<String>.from(
              (data['options'] as List).map((e) => e.toString()))
          : const [],
      optionsAs: data['optionsAs'] is List
          ? List<String>.from(
              (data['optionsAs'] as List).map((e) => e.toString()))
          : const [],
      explanationAs: data['explanationAs']?.toString(),
      correctAnswerIndex: _toInt(data['correctAnswerIndex'], 0),
      explanation: data['explanation']?.toString(),
      subjectTopic: data['subjectTopic']?.toString(),
      marks: _toInt(data['marks'], 1),
      isPremium: data['isPremium'] ?? false,
      imageUrl: data['imageUrl']?.toString(),
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
      'testId': testId,
      'question': question,
      'questionAs': questionAs,
      'options': options,
      'optionsAs': optionsAs,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'explanationAs': explanationAs,
      'subjectTopic': subjectTopic,
      'marks': marks,
      'isPremium': isPremium,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
