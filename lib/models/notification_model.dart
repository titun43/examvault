// =============================================================================
// ExamVault - Notification Model
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

enum NotificationType {
  testResult,
  newTest,
  currentAffair,
  leaderboard,
  premium,
  announcement,
  dailyQuiz,
  general
}

class NotificationModel {
  final String id;
  final String userId; // specific user, or 'all' for broadcast
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? scheduledAt;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = NotificationType.general,
    this.data = const {},
    this.isRead = false,
    this.scheduledAt,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic raw = doc.data();
    if (raw == null) {
      return NotificationModel(
        id: doc.id,
        userId: 'all',
        title: '',
        body: '',
        createdAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    return NotificationModel(
      id: doc.id,
      userId: (data['userId'] ?? 'all').toString(),
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      type: _parseType(data['type']?.toString()),
      data: data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : const {},
      isRead: data['isRead'] ?? false,
      scheduledAt: parseTimestampNullable(data['scheduledAt']),
      createdAt: parseTimestamp(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.name,
      'data': data,
      'isRead': isRead,
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static NotificationType _parseType(String? type) {
    switch (type) {
      case 'testResult': return NotificationType.testResult;
      case 'newTest': return NotificationType.newTest;
      case 'currentAffair': return NotificationType.currentAffair;
      case 'leaderboard': return NotificationType.leaderboard;
      case 'premium': return NotificationType.premium;
      case 'announcement': return NotificationType.announcement;
      case 'dailyQuiz': return NotificationType.dailyQuiz;
      default: return NotificationType.general;
    }
  }
}
