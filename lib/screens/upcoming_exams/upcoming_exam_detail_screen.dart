// =============================================================================
// ExamVault - Upcoming Exam Detail Screen
// Opens when a single exam card is tapped on the Home screen (or from the full
// Upcoming Exams list). Shows the complete information for ONE exam:
// banner image, countdown, full description, application window timeline, and
// every available action link (Apply / Official / Notification / Syllabus).
// Previously tapping a mini-card always opened the full "View All" list — this
// screen gives each exam its own dedicated detail page.
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/upcoming_exam_model.dart';
import '../../utils/share_helper.dart';
import '../../utils/localized_content.dart';

class UpcomingExamDetailScreen extends StatelessWidget {
  final UpcomingExamModel exam;
  const UpcomingExamDetailScreen({super.key, required this.exam});

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';

  String _monthName(int m) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[m - 1];
  }

  Future<void> _launchUrl(BuildContext context, String? rawUrl) async {
    if (rawUrl == null || rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid link')));
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        final ok2 = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        if (!ok2 && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open link')));
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = exam.daysRemaining;
    final isPast = days < 0;
    final isSoon = !isPast && days <= 30;
    final hasImage = exam.imageUrl != null && exam.imageUrl!.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Banner image as a collapsing app bar header (or a plain gradient
          // sliver when no banner image is set).
          SliverAppBar(
            expandedHeight: hasImage ? 220 : 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: hasImage
                  ? CachedNetworkImage(
                      imageUrl: exam.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppTheme.primaryColor,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.primaryColor,
                        child: const Icon(Icons.broken_image,
                            color: Colors.white70, size: 48),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: isPast
                            ? LinearGradient(colors: [
                                Colors.grey.shade500,
                                Colors.grey.shade700
                              ])
                            : isSoon
                                ? AppTheme.accentGradient
                                : AppTheme.primaryGradient,
                      ),
                    ),
            ),
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black38,
                child: Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              // Share button — shares this exam's name, date, description,
              // apply link + the ExamVault Play Store URL. Always visible in
              // the pinned app bar.
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black38,
                    child: Icon(Icons.share, color: Colors.white),
                  ),
                  tooltip: 'Share exam',
                  onPressed: () {
                    ShareHelper.shareExam(exam);
                  },
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Countdown hero
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: isPast
                            ? LinearGradient(colors: [
                                Colors.grey.shade400,
                                Colors.grey.shade500
                              ])
                            : isSoon
                                ? AppTheme.accentGradient
                                : AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (isPast
                                    ? Colors.grey
                                    : isSoon
                                        ? AppTheme.accentColor
                                        : AppTheme.primaryColor)
                                .withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isPast ? '${-days}' : '$days',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            isPast ? 'days ago' : 'days left',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    lc(context, exam.name, exam.nameAs),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  if (exam.organization != null &&
                      exam.organization!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lc(context, exam.organization ?? '', exam.organizationAs),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Exam date card
                  _infoTile(
                    context,
                    icon: Icons.event,
                    label: 'Exam Date',
                    value: _fmtDate(exam.examDate),
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 10),

                  // Application window
                  if (exam.applicationStartDate != null &&
                      exam.applicationEndDate != null) ...[
                    _infoTile(
                      context,
                      icon: Icons.how_to_reg,
                      label: 'Application Window',
                      value:
                          '${_fmtDate(exam.applicationStartDate!)}  →  ${_fmtDate(exam.applicationEndDate!)}',
                      color: exam.applicationOpen
                          ? Colors.green
                          : Colors.grey.shade600,
                      status: exam.applicationOpen
                          ? 'Open'
                          : (DateTime.now().isBefore(exam.applicationStartDate!)
                              ? 'Upcoming'
                              : 'Closed'),
                      statusColor: exam.applicationOpen
                          ? Colors.green
                          : Colors.redAccent,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Tags
                  if (exam.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: exam.tags.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Description
                  if (exam.description.isNotEmpty) ...[
                    const Text(
                      'About this exam',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      lc(context, exam.description, exam.descriptionAs),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action buttons
                  if ((exam.applyUrl != null &&
                          exam.applyUrl!.isNotEmpty) ||
                      (exam.officialUrl != null &&
                          exam.officialUrl!.isNotEmpty) ||
                      (exam.notificationUrl != null &&
                          exam.notificationUrl!.isNotEmpty) ||
                      (exam.syllabusUrl != null &&
                          exam.syllabusUrl!.isNotEmpty)) ...[
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (exam.applyUrl != null && exam.applyUrl!.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _launchUrl(context, exam.applyUrl),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.how_to_reg, size: 18),
                          label: const Text(
                            'Apply Now',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (exam.officialUrl != null &&
                            exam.officialUrl!.isNotEmpty)
                          _secondaryAction(
                            context,
                            icon: Icons.language,
                            label: 'Official Website',
                            url: exam.officialUrl,
                          ),
                        if (exam.notificationUrl != null &&
                            exam.notificationUrl!.isNotEmpty)
                          _secondaryAction(
                            context,
                            icon: Icons.picture_as_pdf,
                            label: 'Notification',
                            url: exam.notificationUrl,
                          ),
                        if (exam.syllabusUrl != null &&
                            exam.syllabusUrl!.isNotEmpty)
                          _secondaryAction(
                            context,
                            icon: Icons.menu_book,
                            label: 'Syllabus',
                            url: exam.syllabusUrl,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? status,
    Color? statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (status != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (statusColor ?? Colors.green).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor ?? Colors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _secondaryAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String? url,
  }) {
    return ActionChip(
      onPressed: () => _launchUrl(context, url),
      avatar: Icon(icon, size: 16, color: AppTheme.primaryColor),
      label: Text(label),
      backgroundColor: AppTheme.primaryColor.withOpacity(0.06),
      side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.2)),
      labelStyle: const TextStyle(
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }
}
