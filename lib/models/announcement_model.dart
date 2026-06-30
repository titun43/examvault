// =============================================================================
// ExamVault - Announcement Model
// Admin-pushed announcements that flow to all users (ticker + dedicated page).
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

enum AnnouncementType { info, success, warning, error, promo }

class AnnouncementModel {
  final String id;
  final String title;
  final String message;
  final AnnouncementType type;
  final String? imageUrl;
  final String? link;       // optional deep-link / external URL
  final String? linkLabel;  // text on the link button (e.g. "Apply Now")
  final bool isPinned;      // sticky at the top of the announcements list
  final bool isPublished;   // draft vs published (only published ones reach users)
  final int order;          // manual ordering
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    this.type = AnnouncementType.info,
    this.imageUrl,
    this.link,
    this.linkLabel,
    this.isPinned = false,
    this.isPublished = true,
    this.order = 0,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnnouncementModel(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: _parseType(data['type']),
      imageUrl: data['imageUrl'],
      link: data['link'],
      linkLabel: data['linkLabel'],
      isPinned: data['isPinned'] ?? false,
      isPublished: data['isPublished'] ?? true,
      order: data['order'] ?? 0,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'type': type.name,
      'imageUrl': imageUrl,
      'link': link,
      'linkLabel': linkLabel,
      'isPinned': isPinned,
      'isPublished': isPublished,
      'order': order,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// True if the announcement is published AND not expired.
  bool get isVisible {
    if (!isPublished) return false;
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) return false;
    return true;
  }

  static AnnouncementType _parseType(String? type) {
    switch (type) {
      case 'success': return AnnouncementType.success;
      case 'warning': return AnnouncementType.warning;
      case 'error': return AnnouncementType.error;
      case 'promo': return AnnouncementType.promo;
      default: return AnnouncementType.info;
    }
  }
}
