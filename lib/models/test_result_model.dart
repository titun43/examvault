// =============================================================================
// ExamVault - Test Result Model
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class TestResultModel {
  final String id;
  final String userId;
  final String testId;
  final String testTitle;
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;
  final int unattempted;
  final int totalMarks;
  final int obtainedMarks;
  final double percentage;
  final bool isPassed;
  final int timeTaken; // seconds
  final int totalTime; // seconds
  final List<int> userAnswers;
  final List<int> correctAnswersList;
  final double accuracy;
  final int rank;
  final DateTime attemptedAt;

  TestResultModel({
    required this.id,
    required this.userId,
    required this.testId,
    required this.testTitle,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
    required this.unattempted,
    required this.totalMarks,
    required this.obtainedMarks,
    required this.percentage,
    required this.isPassed,
    required this.timeTaken,
    required this.totalTime,
    required this.userAnswers,
    required this.correctAnswersList,
    required this.accuracy,
    this.rank = 0,
    required this.attemptedAt,
  });

  factory TestResultModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TestResultModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      testId: data['testId'] ?? '',
      testTitle: data['testTitle'] ?? '',
      totalQuestions: data['totalQuestions'] ?? 0,
      correctAnswers: data['correctAnswers'] ?? 0,
      wrongAnswers: data['wrongAnswers'] ?? 0,
      unattempted: data['unattempted'] ?? 0,
      totalMarks: data['totalMarks'] ?? 0,
      obtainedMarks: data['obtainedMarks'] ?? 0,
      percentage: (data['percentage'] ?? 0).toDouble(),
      isPassed: data['isPassed'] ?? false,
      timeTaken: data['timeTaken'] ?? 0,
      totalTime: data['totalTime'] ?? 0,
      userAnswers: List<int>.from(data['userAnswers'] ?? []),
      correctAnswersList: List<int>.from(data['correctAnswersList'] ?? []),
      accuracy: (data['accuracy'] ?? 0).toDouble(),
      rank: data['rank'] ?? 0,
      attemptedAt: (data['attemptedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'testId': testId,
      'testTitle': testTitle,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'unattempted': unattempted,
      'totalMarks': totalMarks,
      'obtainedMarks': obtainedMarks,
      'percentage': percentage,
      'isPassed': isPassed,
      'timeTaken': timeTaken,
      'totalTime': totalTime,
      'userAnswers': userAnswers,
      'correctAnswersList': correctAnswersList,
      'accuracy': accuracy,
      'rank': rank,
      'attemptedAt': Timestamp.fromDate(attemptedAt),
    };
  }
}
