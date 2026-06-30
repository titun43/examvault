// =============================================================================
// ExamVault - Question Model
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

class QuestionModel {
  final String id;
  final String testId;
  final String question;
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
    final data = doc.data() as Map<String, dynamic>;
    return QuestionModel(
      id: doc.id,
      testId: data['testId'] ?? '',
      question: data['question'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswerIndex: data['correctAnswerIndex'] ?? 0,
      explanation: data['explanation'],
      subjectTopic: data['subjectTopic'],
      marks: data['marks'] ?? 1,
      isPremium: data['isPremium'] ?? false,
      imageUrl: data['imageUrl'],
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'testId': testId,
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      'subjectTopic': subjectTopic,
      'marks': marks,
      'isPremium': isPremium,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
