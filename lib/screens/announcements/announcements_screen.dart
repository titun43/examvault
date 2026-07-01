// =============================================================================
// ExamVault - User Announcements Screen
// Shows all published announcements (admin pushes → user sees here + ticker)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/announcement_model.dart';
import '../../services/firestore_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey.shade50 : Colors.black87;
    final subtitleColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final mutedColor = isDark ? Colors.grey.shade400 : Colors.grey.shade500;
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
      child: Padding(
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
                    a.title,
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
              a.message,
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
                if (a.link != null && a.link!.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(a.link!);
                      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: Text(a.linkLabel ?? 'Open Link'),
                    style: TextButton.styleFrom(
                      foregroundColor: _typeColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
