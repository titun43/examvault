// =============================================================================
// ExamVault - Banner Model
// Home-screen carousel banners. Admin uploads an image + up to two CTA
// buttons. Each button is independently configured (external link OR in-app
// screen). Users see the carousel at the top of the Home screen.
//
// Backward compatibility: older banners only had a single `link` + `linkLabel`
// field (external URL only). When a banner has no `primaryButton` set, the
// old `link`/`linkLabel` is treated as the primary external button so legacy
// banners keep working unchanged.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';
import 'action_button.dart';

class BannerModel {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;         // required — banner image (Storage URL)

  // Legacy single-link fields (kept for backward compat + simple admin edits).
  // When primaryButton is null, these are used as the primary external button.
  final String? link;
  final String? linkLabel;

  // New two-button system. Each is optional (admin can set 0, 1, or 2).
  final ActionButton? primaryButton;
  final ActionButton? secondaryButton;

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
    this.primaryButton,
    this.secondaryButton,
    this.order = 0,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BannerModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic raw = doc.data();
    if (raw == null) {
      return BannerModel(
        id: doc.id,
        title: '',
        imageUrl: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);

    // Parse the two new button slots. Each may be stored as a Map or absent.
    final ActionButton? primary =
        ActionButton.fromDynamic(data['primaryButton']);
    final ActionButton? secondary =
        ActionButton.fromDynamic(data['secondaryButton']);

    // Legacy fields (still written by older admin code / manual console edits).
    final String? legacyLink = data['link']?.toString();
    final String? legacyLabel = data['linkLabel']?.toString();

    // Backward-compat bridge: if no explicit primaryButton was stored but the
    // legacy link/linkLabel fields are present, synthesize a primary external
    // button from them so the banner still shows one tappable CTA.
    final ActionButton? effectivePrimary = primary ??
        (legacyLink != null && legacyLink.isNotEmpty
            ? ActionButton(
                label: (legacyLabel != null && legacyLabel.isNotEmpty)
                    ? legacyLabel
                    : 'Open Link',
                type: ActionType.external,
                url: legacyLink,
              )
            : null);

    return BannerModel(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      subtitle: data['subtitle']?.toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      link: legacyLink,
      linkLabel: legacyLabel,
      primaryButton: effectivePrimary,
      secondaryButton: secondary,
      order: _toInt(data['order'], 0),
      isActive: data['isActive'] ?? true,
      startsAt: parseTimestampNullable(data['startsAt']),
      endsAt: parseTimestampNullable(data['endsAt']),
      createdAt: parseTimestamp(data['createdAt']),
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

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      // Keep writing the legacy fields too so older app builds still see a
      // link if they haven't updated to the two-button model yet.
      'link': link,
      'linkLabel': linkLabel,
      'primaryButton': primaryButton?.toMap(),
      'secondaryButton': secondaryButton?.toMap(),
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
