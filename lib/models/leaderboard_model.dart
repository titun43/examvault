// =============================================================================
// ExamVault - Leaderboard Model
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

enum LeaderboardType { weekly, monthly, allTime, testSpecific }

class LeaderboardModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final int totalXp;
  final int totalTestsAttempted;
  final double averageScore;
  final int rank;
  final int streak;
  final LeaderboardType type;
  final String? testId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime updatedAt;

  LeaderboardModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.totalXp,
    required this.totalTestsAttempted,
    required this.averageScore,
    required this.rank,
    this.streak = 0,
    this.type = LeaderboardType.allTime,
    this.testId,
    required this.periodStart,
    required this.periodEnd,
    required this.updatedAt,
  });

  factory LeaderboardModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic raw = doc.data();
    if (raw == null) {
      return LeaderboardModel(
        id: doc.id,
        userId: '',
        userName: '',
        totalXp: 0,
        totalTestsAttempted: 0,
        averageScore: 0,
        rank: 0,
        periodStart: DateTime.now(),
        periodEnd: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    return LeaderboardModel(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? '').toString(),
      userPhoto: data['userPhoto']?.toString(),
      totalXp: _toInt(data['totalXp'], 0),
      totalTestsAttempted: _toInt(data['totalTestsAttempted'], 0),
      averageScore: _toDouble(data['averageScore'], 0),
      rank: _toInt(data['rank'], 0),
      streak: _toInt(data['streak'], 0),
      type: _parseType(data['type']?.toString()),
      testId: data['testId']?.toString(),
      periodStart: parseTimestamp(data['periodStart']),
      periodEnd: parseTimestamp(data['periodEnd']),
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
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'totalXp': totalXp,
      'totalTestsAttempted': totalTestsAttempted,
      'averageScore': averageScore,
      'rank': rank,
      'streak': streak,
      'type': type.name,
      'testId': testId,
      'periodStart': Timestamp.fromDate(periodStart),
      'periodEnd': Timestamp.fromDate(periodEnd),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static LeaderboardType _parseType(String? type) {
    switch (type) {
      case 'weekly': return LeaderboardType.weekly;
      case 'monthly': return LeaderboardType.monthly;
      case 'testSpecific': return LeaderboardType.testSpecific;
      default: return LeaderboardType.allTime;
    }
  }
}
