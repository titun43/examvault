// =============================================================================
// ExamVault - Banner Model
// Home-screen carousel banners. Admin uploads an image + optional link → users
// see the carousel at the top of the Home screen.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';

class BannerModel {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;         // required — banner image (Storage URL)
  final String? link;            // optional deep-link / external URL
  final String? linkLabel;       // optional CTA text
  final int order;               // manual ordering (lower = first)
  final bool isActive;
  final DateTime? startsAt;      // optional scheduling
  final DateTime? endsAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  BannerModel({
    required this.id,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.link,
    this.linkLabel,
    this.order = 0,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BannerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BannerModel(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'],
      imageUrl: data['imageUrl'] ?? '',
      link: data['link'],
      linkLabel: data['linkLabel'],
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? true,
      startsAt: parseTimestampNullable(data['startsAt']),
      endsAt: parseTimestampNullable(data['endsAt']),
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'link': link,
      'linkLabel': linkLabel,
      'order': order,
      'isActive': isActive,
      'startsAt': startsAt != null ? Timestamp.fromDate(startsAt!) : null,
      'endsAt': endsAt != null ? Timestamp.fromDate(endsAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// True if banner is active AND within its scheduled window (if any).
  bool get isVisible {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }
}
