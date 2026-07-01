// =============================================================================
// ExamVault - Test Result Model
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

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
    final dynamic raw = doc.data();
    if (raw == null) {
      return TestResultModel(
        id: doc.id,
        userId: '',
        testId: '',
        testTitle: '',
        totalQuestions: 0,
        correctAnswers: 0,
        wrongAnswers: 0,
        unattempted: 0,
        totalMarks: 0,
        obtainedMarks: 0,
        percentage: 0,
        isPassed: false,
        timeTaken: 0,
        totalTime: 0,
        userAnswers: const [],
        correctAnswersList: const [],
        accuracy: 0,
        attemptedAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    return TestResultModel(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      testId: (data['testId'] ?? '').toString(),
      testTitle: (data['testTitle'] ?? '').toString(),
      totalQuestions: _toInt(data['totalQuestions'], 0),
      correctAnswers: _toInt(data['correctAnswers'], 0),
      wrongAnswers: _toInt(data['wrongAnswers'], 0),
      unattempted: _toInt(data['unattempted'], 0),
      totalMarks: _toInt(data['totalMarks'], 0),
      obtainedMarks: _toInt(data['obtainedMarks'], 0),
      percentage: _toDouble(data['percentage'], 0),
      isPassed: data['isPassed'] ?? false,
      timeTaken: _toInt(data['timeTaken'], 0),
      totalTime: _toInt(data['totalTime'], 0),
      userAnswers: data['userAnswers'] is List
          ? List<int>.from((data['userAnswers'] as List)
              .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0))
          : const [],
      correctAnswersList: data['correctAnswersList'] is List
          ? List<int>.from((data['correctAnswersList'] as List)
              .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0))
          : const [],
      accuracy: _toDouble(data['accuracy'], 0),
      rank: _toInt(data['rank'], 0),
      attemptedAt: parseTimestamp(data['attemptedAt']),
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
