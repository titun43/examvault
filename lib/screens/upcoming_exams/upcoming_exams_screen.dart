// =============================================================================
// ExamVault - User Upcoming Exams Screen
// Shows all published upcoming exams with countdown + apply link
// =============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/upcoming_exam_model.dart';
import '../../services/firestore_service.dart';
import '../../services/category_preference_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/share_helper.dart';
import '../../utils/localized_content.dart';
import '../onboarding/category_selection_screen.dart';

class UpcomingExamsScreen extends StatefulWidget {
  const UpcomingExamsScreen({super.key});

  @override
  State<UpcomingExamsScreen> createState() => _UpcomingExamsScreenState();
}

class _UpcomingExamsScreenState extends State<UpcomingExamsScreen> {
  List<String> _preferredCategoryIds = [];
  bool _ready = false;
  // AuthProvider reference for listening to preferred-category changes
  // (so Profile > My Categories propagates live to this screen).
  AuthProvider? _auth;

  @override
  void initState() {
    super.initState();
    _load();
    // Reactivity: refresh preferred ids when AuthProvider notifies (e.g.
    // after Profile > My Categories saves a new selection in another tab).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _auth = Provider.of<AuthProvider>(context, listen: false);
      _auth!.addListener(_onAuthChanged);
    });
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ids = await CategoryPreferenceService.getSelectedCategoryIds(auth.user);
    if (!mounted) return;
    // Skip no-op rebuilds when AuthProvider notifies for unrelated reasons
    // (premium purchase, streak update, etc.).
    bool same = ids.length == _preferredCategoryIds.length;
    if (same) {
      for (var i = 0; i < ids.length; i++) {
        if (ids[i] != _preferredCategoryIds[i]) { same = false; break; }
      }
    }
    if (same && _ready) return;
    setState(() {
      _preferredCategoryIds = ids;
      _ready = true;
    });
  }

  Future<void> _openManageCategories() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CategorySelectionScreen(isOnboarding: false),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upcoming Exams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'My Categories',
            onPressed: _openManageCategories,
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<UpcomingExamModel>>(
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
          // Default to the user's selected categories (from onboarding /
          // Profile > My Categories). Falls back to everything if nothing
          // is selected, or if the selection matches nothing here (an exam
          // with no categoryId, or ids that don't line up).
          var list = snapshot.data!;
          if (_preferredCategoryIds.isNotEmpty) {
            final filtered = list
                .where((e) =>
                    e.categoryId != null &&
                    _preferredCategoryIds.contains(e.categoryId))
                .toList();
            if (filtered.isNotEmpty) list = filtered;
          }
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
    // Admin-uploaded banner image — shown at the top of the card when present.
    final hasImage = exam.imageUrl != null && exam.imageUrl!.isNotEmpty;

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
      // Clip children so the banner image inherits the card's rounded corners.
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            CachedNetworkImage(
              imageUrl: exam.imageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 140,
              placeholder: (_, __) => Container(
                color: Colors.grey.shade200,
                width: double.infinity,
                height: 140,
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                width: double.infinity,
                height: 140,
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
                        lc(context, exam.name, exam.nameAs),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (exam.organization != null && exam.organization!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          lc(context, exam.organization ?? '', exam.organizationAs),
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
                lc(context, exam.description, exam.descriptionAs),
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
            // Action area: Apply (primary) + secondary links (Official /
            // Notification / Syllabus). Each shown only when its URL is present.
            // Renders only if at least one of the four URLs is set.
            if ((exam.applyUrl != null && exam.applyUrl!.isNotEmpty) ||
                (exam.officialUrl != null && exam.officialUrl!.isNotEmpty) ||
                (exam.notificationUrl != null && exam.notificationUrl!.isNotEmpty) ||
                (exam.syllabusUrl != null && exam.syllabusUrl!.isNotEmpty)) ...[
              const SizedBox(height: 12),
              if (exam.applyUrl != null && exam.applyUrl!.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(exam.applyUrl!);
                      if (uri == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invalid link')));
                        return;
                      }
                      try {
                        final ok = await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                        if (!ok) {
                          final ok2 = await launchUrl(uri,
                              mode: LaunchMode.inAppBrowserView);
                          if (!ok2 && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Could not open link')));
                          }
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Could not open link')));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.how_to_reg, size: 18),
                    label: const Text(
                      'Apply Now',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                ),
              if (exam.applyUrl != null && exam.applyUrl!.isNotEmpty)
                const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  if (exam.officialUrl != null && exam.officialUrl!.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(exam.officialUrl!);
                        if (uri == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid link')));
                          return;
                        }
                        try {
                          final ok = await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                          if (!ok) {
                            final ok2 = await launchUrl(uri,
                                mode: LaunchMode.inAppBrowserView);
                            if (!ok2 && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Could not open link')));
                            }
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Could not open link')));
                          }
                        }
                      },
                      icon: const Icon(Icons.language, size: 16),
                      label: const Text('Official'),
                    ),
                  if (exam.notificationUrl != null &&
                      exam.notificationUrl!.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(exam.notificationUrl!);
                        if (uri == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid link')));
                          return;
                        }
                        try {
                          final ok = await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                          if (!ok) {
                            final ok2 = await launchUrl(uri,
                                mode: LaunchMode.inAppBrowserView);
                            if (!ok2 && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Could not open link')));
                            }
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Could not open link')));
                          }
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('Notification'),
                    ),
                  if (exam.syllabusUrl != null && exam.syllabusUrl!.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(exam.syllabusUrl!);
                        if (uri == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid link')));
                          return;
                        }
                        try {
                          final ok = await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                          if (!ok) {
                            final ok2 = await launchUrl(uri,
                                mode: LaunchMode.inAppBrowserView);
                            if (!ok2 && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Could not open link')));
                            }
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Could not open link')));
                          }
                        }
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
          // Share row — always visible so the user can share any exam (mirrors
          // the Current Affairs list card). Shares via ShareHelper.shareExam
          // which always appends the ExamVault Play Store link.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => ShareHelper.shareExam(exam),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Share'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
