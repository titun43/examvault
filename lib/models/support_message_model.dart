// =============================================================================
// ExamVault - Support Message Model
// A single chat message inside a support ticket.
//
// Firestore path: support_tickets/{ticketId}/messages/{messageId}
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

enum MessageSender { user, admin, system }

class SupportMessageModel {
  final String id;
  final MessageSender sender;
  final String text;
  final DateTime createdAt;

  SupportMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.createdAt,
  });

  factory SupportMessageModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic raw = doc.data();
    if (raw == null) {
      return SupportMessageModel(
        id: doc.id,
        sender: MessageSender.user,
        text: '',
        createdAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);

    final senderStr = (data['sender'] ?? 'user').toString();
    final MessageSender sender;
    switch (senderStr) {
      case 'admin':
        sender = MessageSender.admin;
        break;
      case 'system':
        sender = MessageSender.system;
        break;
      default:
        sender = MessageSender.user;
    }

    return SupportMessageModel(
      id: doc.id,
      sender: sender,
      text: (data['text'] ?? '').toString(),
      createdAt: parseTimestamp(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    String senderStr;
    switch (sender) {
      case MessageSender.admin:
        senderStr = 'admin';
        break;
      case MessageSender.system:
        senderStr = 'system';
        break;
      case MessageSender.user:
        senderStr = 'user';
        break;
    }
    return {
      'sender': senderStr,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
