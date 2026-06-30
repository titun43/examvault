// =============================================================================
// ExamVault - User Upcoming Exams Screen
// Shows all published upcoming exams with countdown + apply link
// =============================================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/upcoming_exam_model.dart';
import '../../services/firestore_service.dart';

class UpcomingExamsScreen extends StatelessWidget {
  const UpcomingExamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Exams')),
      body: StreamBuilder<List<UpcomingExamModel>>(
        stream: FirestoreService.getUpcomingExamsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No upcoming exams yet',
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
              return _UpcomingExamCard(exam: list[index]);
            },
          );
        },
      ),
    );
  }
}

class _UpcomingExamCard extends StatelessWidget {
  final UpcomingExamModel exam;
  const _UpcomingExamCard({required this.exam});

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';

  String _monthName(int m) {
    const names = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return names[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final days = exam.daysRemaining;
    final isPast = days < 0;
    final isSoon = !isPast && days <= 30;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Countdown badge
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: isPast
                        ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500])
                        : isSoon
                            ? AppTheme.accentGradient
                            : AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isPast ? '${-days}' : '$days',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        isPast ? 'days ago' : 'days left',
                        style: const TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (exam.organization != null && exam.organization!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          exam.organization!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.event, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            _fmtDate(exam.examDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      if (exam.applicationStartDate != null &&
                          exam.applicationEndDate != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.how_to_reg, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Apply: ${_fmtDate(exam.applicationStartDate!)} → ${_fmtDate(exam.applicationEndDate!)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: exam.applicationOpen
                                      ? Colors.green
                                      : Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (exam.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                exam.description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (exam.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: exam.tags.map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (exam.notificationUrl != null && exam.notificationUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(exam.notificationUrl!);
                      if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('Notification'),
                  ),
                  if (exam.syllabusUrl != null && exam.syllabusUrl!.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(exam.syllabusUrl!);
                        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.menu_book, size: 16),
                      label: const Text('Syllabus'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
