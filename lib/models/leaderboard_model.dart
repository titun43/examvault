// =============================================================================
// ExamVault - Leaderboard Model
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

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
    final data = doc.data() as Map<String, dynamic>;
    return LeaderboardModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhoto: data['userPhoto'],
      totalXp: data['totalXp'] ?? 0,
      totalTestsAttempted: data['totalTestsAttempted'] ?? 0,
      averageScore: (data['averageScore'] ?? 0).toDouble(),
      rank: data['rank'] ?? 0,
      streak: data['streak'] ?? 0,
      type: _parseType(data['type']),
      testId: data['testId'],
      periodStart: (data['periodStart'] as Timestamp).toDate(),
      periodEnd: (data['periodEnd'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
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
