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

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: StreamBuilder<List<AnnouncementModel>>(
        stream: FirestoreService.getAnnouncementsStream(),
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
                  Text('No announcements yet',
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
      case AnnouncementType.success: return Colors.green;
      case AnnouncementType.warning: return Colors.orange;
      case AnnouncementType.error: return Colors.red;
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

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
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
                // LIVE pulsing badge — shows on every active announcement so
                // users see the same "LIVE" indicator the admin preview has.
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (a.isPinned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin, size: 10, color: Colors.orange),
                        SizedBox(width: 2),
                        Text('Pinned', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600)),
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
                  _timeAgo(a.createdAt),
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
