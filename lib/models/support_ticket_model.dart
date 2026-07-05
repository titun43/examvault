// =============================================================================
// ExamVault - Support Ticket Model
// A user-created support ticket shown in the in-app Help & Support screen and
// in the admin panel's Support section. Each ticket has a subcollection of
// messages (see support_message_model.dart).
//
// Firestore path: support_tickets/{ticketId}
//                  └── messages/{messageId}
//
// Security (firestore.rules):
//   - user can read/create/update only their OWN tickets
//   - admin can read/update ALL tickets (e.g. mark resolved)
//   - messages: owner of parent ticket OR admin
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

enum TicketStatus { open, resolved }

class SupportTicketModel {
  final String id;
  final String userId;
  final String userName;
  final String? userEmail;
  final String? userPhone;

  final String subject;

  /// Preview of the most recent message (denormalized so the list view can
  /// show a preview without reading the messages subcollection).
  final String lastMessage;

  /// Sender of the most recent message: 'user' or 'admin'.
  final String lastSender;

  final TicketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupportTicketModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userEmail,
    this.userPhone,
    required this.subject,
    this.lastMessage = '',
    this.lastSender = 'user',
    this.status = TicketStatus.open,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicketModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic raw = doc.data();
    if (raw == null) {
      return SupportTicketModel(
        id: doc.id,
        userId: '',
        userName: '',
        subject: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);

    return SupportTicketModel(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      userName: (data['userName'] ?? 'User').toString(),
      userEmail: data['userEmail']?.toString(),
      userPhone: data['userPhone']?.toString(),
      subject: (data['subject'] ?? '').toString(),
      lastMessage: (data['lastMessage'] ?? '').toString(),
      lastSender: (data['lastSender'] ?? 'user').toString(),
      status: data['status'] == 'resolved'
          ? TicketStatus.resolved
          : TicketStatus.open,
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'subject': subject,
      'lastMessage': lastMessage,
      'lastSender': lastSender,
      'status': status == TicketStatus.resolved ? 'resolved' : 'open',
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SupportTicketModel copyWith({
    String? lastMessage,
    String? lastSender,
    TicketStatus? status,
    DateTime? updatedAt,
  }) {
    return SupportTicketModel(
      id: id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
      subject: subject,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSender: lastSender ?? this.lastSender,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
