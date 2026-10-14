// ignore_for_file: unreachable_switch_default
// =============================================================================
// ExamVault - App Open Banner Model
// =============================================================================
// Full-screen promotional banner shown ONCE per app launch (splash → home
// transition). Admin uploads a full-screen image + optional CTA button.
//
// Frequency control (admin-set per banner):
//   - 'once_per_day' : shown at most once per calendar day per device
//   - 'once_per_session' : shown at most once per app launch (default)
//   - 'every_open' : always shown on every app open
//
// Urgent override: when [isUrgent] is true, the frequency cap is ignored
// and the banner is shown even if the user already saw it today.
//
// Target audience: admin can restrict a banner to 'all', 'guest',
// 'free' (signed-in non-premium), or 'premium' users.
//
// The CTA button reuses [ActionButton] so destinations can be either an
// external URL or an in-app screen (handled by InAppNavigator).
//
// Analytics: [impressionCount] and [clickCount] are incremented server-side
// via FieldValue.increment when the banner is shown / clicked.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_helpers.dart';
import 'action_button.dart';

/// Frequency cap options for an app-open banner.
enum AppOpenBannerFrequency {
  oncePerDay,
  oncePerSession,
  everyOpen;

  static AppOpenBannerFrequency fromString(String? v) {
    switch (v) {
      case 'once_per_day':
        return AppOpenBannerFrequency.oncePerDay;
      case 'every_open':
        return AppOpenBannerFrequency.everyOpen;
      case 'once_per_session':
      default:
        return AppOpenBannerFrequency.oncePerSession;
    }
  }

  String get wire {
    switch (this) {
      case AppOpenBannerFrequency.oncePerDay:
        return 'once_per_day';
      case AppOpenBannerFrequency.everyOpen:
        return 'every_open';
      case AppOpenBannerFrequency.oncePerSession:
      default:
        return 'once_per_session';
    }
  }
}

/// Target audience options.
enum AppOpenBannerAudience {
  all,
  guest,
  free,
  premium;

  static AppOpenBannerAudience fromString(String? v) {
    switch (v) {
      case 'guest':
        return AppOpenBannerAudience.guest;
      case 'free':
        return AppOpenBannerAudience.free;
      case 'premium':
        return AppOpenBannerAudience.premium;
      case 'all':
      default:
        return AppOpenBannerAudience.all;
    }
  }

  String get wire {
    switch (this) {
      case AppOpenBannerAudience.guest:
        return 'guest';
      case AppOpenBannerAudience.free:
        return 'free';
      case AppOpenBannerAudience.premium:
        return 'premium';
      case AppOpenBannerAudience.all:
      default:
        return 'all';
    }
  }
}

class AppOpenBannerModel {
  final String id;
  final String imageUrl;        // required — full-screen image
  final String? title;          // optional overlay text
  final String? subtitle;       // optional overlay text
  final ActionButton? primaryButton; // optional CTA button
  final int priority;           // higher = shown first
  final bool isActive;
  final DateTime? startsAt;     // scheduled start
  final DateTime? endsAt;       // scheduled end
  final AppOpenBannerFrequency frequency;
  final bool isUrgent;          // ignore frequency cap
  final AppOpenBannerAudience targetAudience;
  final int impressionCount;
  final int clickCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppOpenBannerModel({
    required this.id,
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.primaryButton,
    this.priority = 0,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
    this.frequency = AppOpenBannerFrequency.oncePerSession,
    this.isUrgent = false,
    this.targetAudience = AppOpenBannerAudience.all,
    this.impressionCount = 0,
    this.clickCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppOpenBannerModel.fromFirestore(DocumentSnapshot doc) {
    final dynamic raw = doc.data();
    if (raw == null) {
      return AppOpenBannerModel(
        id: doc.id,
        imageUrl: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);

    return AppOpenBannerModel(
      id: doc.id,
      imageUrl: (data['imageUrl'] ?? '').toString(),
      title: data['title']?.toString().trim().isEmpty == true
          ? null
          : data['title']?.toString(),
      subtitle: data['subtitle']?.toString().trim().isEmpty == true
          ? null
          : data['subtitle']?.toString(),
      primaryButton: ActionButton.fromDynamic(data['primaryButton']),
      priority: _toInt(data['priority'], 0),
      isActive: data['isActive'] ?? true,
      startsAt: parseTimestampNullable(data['startsAt']),
      endsAt: parseTimestampNullable(data['endsAt']),
      frequency: AppOpenBannerFrequency.fromString(
        data['frequency']?.toString(),
      ),
      isUrgent: data['isUrgent'] ?? false,
      targetAudience: AppOpenBannerAudience.fromString(
        data['targetAudience']?.toString(),
      ),
      impressionCount: _toInt(data['impressionCount'], 0),
      clickCount: _toInt(data['clickCount'], 0),
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
      'imageUrl': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'primaryButton': primaryButton?.toMap(),
      'priority': priority,
      'isActive': isActive,
      'startsAt': startsAt != null ? Timestamp.fromDate(startsAt!) : null,
      'endsAt': endsAt != null ? Timestamp.fromDate(endsAt!) : null,
      'frequency': frequency.wire,
      'isUrgent': isUrgent,
      'targetAudience': targetAudience.wire,
      'impressionCount': impressionCount,
      'clickCount': clickCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// True if banner is active AND within its scheduled window (if any).
  bool get isVisibleNow {
    if (!isActive) return false;
    if (imageUrl.isEmpty) return false;
    final now = DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }

  /// Returns true if this banner should be shown to the given user type.
  bool matchesAudience({required bool isGuest, required bool isPremium}) {
    switch (targetAudience) {
      case AppOpenBannerAudience.all:
        return true;
      case AppOpenBannerAudience.guest:
        return isGuest;
      case AppOpenBannerAudience.free:
        return !isGuest && !isPremium;
      case AppOpenBannerAudience.premium:
        return isPremium;
    }
  }
}
