// =============================================================================
// ExamVault - User Announcements Screen
// Shows all published announcements (admin pushes → user sees here + ticker)
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/announcement_model.dart';
import '../../models/action_button.dart';
import '../../services/firestore_service.dart';
import '../../utils/in_app_navigator.dart';
import '../../utils/localized_content.dart';
import '../../l10n/app_localizations.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  // Cached Firestore stream. Creating the stream inline inside build() is a
  // Flutter anti-pattern: every parent rebuild (e.g. theme toggle) hands the
  // StreamBuilder a BRAND-NEW stream object, so Flutter cancels the old
  // subscription and re-subscribes -> resets connection state to "waiting"
  // -> spinner flash. Cache it once in initState instead.
  late final Stream<List<AnnouncementModel>> _announcementsStream;

  @override
  void initState() {
    super.initState();
    // Cache the stream ONCE so theme toggles don't re-fetch from Firestore.
    _announcementsStream = FirestoreService.getAnnouncementsStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'announcements_title'))),
      body: StreamBuilder<List<AnnouncementModel>>(
        // Cached in initState — see _announcementsStream field doc.
        stream: _announcementsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(tr(context, 'announcements_empty'),
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }
          final list = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final a = list[index];
              return _AnnouncementCard(announcement: a);
            },
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final AnnouncementModel announcement;
  const _AnnouncementCard({required this.announcement});

  Color get _typeColor {
    switch (announcement.type) {
      case AnnouncementType.success: return AppTheme.successColor;
      case AnnouncementType.warning: return AppTheme.warningColor;
      case AnnouncementType.error: return AppTheme.errorColor;
      case AnnouncementType.promo: return AppTheme.accentColor;
      default: return AppTheme.primaryColor;
    }
  }

  IconData get _typeIcon {
    switch (announcement.type) {
      case AnnouncementType.success: return Icons.check_circle_outline;
      case AnnouncementType.warning: return Icons.warning_amber;
      case AnnouncementType.error: return Icons.error_outline;
      case AnnouncementType.promo: return Icons.local_offer;
      default: return Icons.info_outline;
    }
  }

  String _timeAgo(BuildContext context, DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${tr(context, 'announcements_min_ago')}';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} ${tr(context, 'announcements_hour_ago')}';
    }
    if (diff.inDays < 30) {
      return '${diff.inDays} ${tr(context, 'announcements_day_ago')}';
    }
    return '${d.day}/${d.month}/${d.year}';
  }

  /// Renders a single CTA button. Primary buttons are filled with the
  /// announcement's type color; secondary buttons are outlined. Each runs
  /// only its own [ActionButton] on tap via [runActionButton].
  Widget _buildActionButton(
    BuildContext context,
    ActionButton button, {
    required bool isPrimary,
  }) {
    final icon = button.type == ActionType.inApp
        ? Icons.arrow_forward_rounded
        : Icons.open_in_new;
    if (isPrimary) {
      return TextButton.icon(
        onPressed: () => runActionButton(context, button),
        icon: Icon(icon, size: 14),
        label: Text(button.label),
        style: TextButton.styleFrom(
          foregroundColor: _typeColor,
          backgroundColor: _typeColor.withOpacity(0.1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: const Size(0, 32),
        ),
      );
    }
    return TextButton.icon(
      onPressed: () => runActionButton(context, button),
      icon: Icon(icon, size: 14),
      label: Text(button.label),
      style: TextButton.styleFrom(
        foregroundColor: _typeColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey.shade50 : Colors.black87;
    final subtitleColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final mutedColor = isDark ? Colors.grey.shade400 : Colors.grey.shade500;
    // Admin-uploaded banner image — shown at the top of the card when present.
    final hasImage = a.imageUrl != null && a.imageUrl!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: _typeColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // Clip children so the banner image inherits the card's rounded corners.
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            CachedNetworkImage(
              imageUrl: a.imageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 160,
              placeholder: (_, __) => Container(
                color: Colors.grey.shade200,
                width: double.infinity,
                height: 160,
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                width: double.infinity,
                height: 160,
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              children: [
                Icon(_typeIcon, color: _typeColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lc(context, a.title, a.titleAs),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
                // Issue #26: the LIVE pulsing badge used to show on EVERY
                // announcement regardless of age. Now it only shows for
                // recent announcements (created within the last 24h). For
                // older pinned announcements, show a static non-pulsing grey
                // "PINNED" badge instead — older announcements don't need to
                // shout "LIVE" at the user.
                if (a.createdAt
                    .isAfter(DateTime.now().subtract(const Duration(hours: 24))))
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.errorColor.withOpacity(0.4),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, size: 6, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          tr(context, 'announcements_live_badge'),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (a.isPinned)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin,
                            size: 10, color: Colors.grey.shade600),
                        const SizedBox(width: 2),
                        Text(
                          tr(context, 'announcements_pinned_badge'),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lc(context, a.message, a.messageAs),
              style: TextStyle(
                fontSize: 14,
                color: subtitleColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  _timeAgo(context, a.createdAt),
                  style: TextStyle(fontSize: 11, color: mutedColor),
                ),
                const Spacer(),
                // Up to two CTA buttons, each independently configured by the
                // admin as an external link OR an in-app screen. Tapping a
                // button runs only its own action.
                if (a.primaryButton != null && a.primaryButton!.isSet)
                  _buildActionButton(context, a.primaryButton!, isPrimary: true),
                if (a.secondaryButton != null && a.secondaryButton!.isSet) ...[
                  const SizedBox(width: 6),
                  _buildActionButton(context, a.secondaryButton!, isPrimary: false),
                ],
              ],
            ),
          ],
        ),
      ),
          ],
        ),
    );
  }
}
