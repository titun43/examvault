// =============================================================================
// ExamVault - Subject Detail Screen (Content Hub)
// =============================================================================
// This is the HUB screen that appears when a user taps a subject from the
// Category Detail screen. It shows:
//
//   1. A hero header with the subject name, icon, description, and category.
//   2. A grid of CONTENT TYPE CARDS:
//        📝 Tests             — always shown (navigates to TestListScreen)
//        📄 Previous Papers   — shown ONLY if the admin has added ≥1 paper
//        📖 Study Notes       — shown ONLY if the admin has added ≥1 note
//        📋 Syllabus          — shown ONLY if the admin has added ≥1 syllabus
//
// REAL-TIME BEHAVIOR (the key feature):
//   The study_materials collection is streamed in real-time. When the admin
//   adds the first "Previous Paper" for this subject, the "📄 Previous Papers"
//   card appears on the user's screen within 1-2 seconds — automatically,
//   without any pull-to-refresh. When the admin deletes the last paper, the
//   card disappears. This is the professional pattern used by Testbook /
//   Gradeup: empty content types are simply not shown.
//
//   The Tests card uses SubjectModel.testCount (a denormalized field kept
//   in sync by the admin's subjects.tsx component). It is always shown because
//   every subject has at least the seeded mock/practice tests.
// =============================================================================

import 'package:flutter/material.dart';
import '../../models/study_material_model.dart';
import '../../models/subject_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/connectivity_banner.dart';
import '../../widgets/offline_aware_stream_builder.dart';
import '../tests/test_list_screen.dart';
import '../study_materials/material_list_screen.dart';

class SubjectDetailScreen extends StatefulWidget {
  final SubjectModel subject;
  // The authoritative category Firestore id — forwarded to TestListScreen
  // so the server-side access check (exam pack) uses the real id, not the
  // subject's possibly-name/slug categoryId. See the comment in
  // category_detail_screen.dart > _buildSubjectCard for why this matters.
  final String? categoryId;
  final String? categoryName;

  const SubjectDetailScreen({
    super.key,
    required this.subject,
    this.categoryId,
    this.categoryName,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header with subject info
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryDarkColor,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  subject.icon ?? '📚',
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.categoryName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.categoryName!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (subject.description != null &&
                            subject.description!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            subject.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Connectivity banner (sliver-friendly: wrap in SliverToBoxAdapter)
          SliverToBoxAdapter(
            child: Column(
              children: const [
                ConnectivityBanner(),
              ],
            ),
          ),

          // Content type grid + recent materials
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Study Material',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap a category below to browse content',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Content type grid — built from the real-time stream
                  _ContentTypeGrid(
                    subject: subject,
                    categoryId: widget.categoryId,
                    categoryName: widget.categoryName,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The real-time content-type grid. Subscribes to the study_materials stream
/// for this subject and shows a card for each type that has content.
class _ContentTypeGrid extends StatelessWidget {
  final SubjectModel subject;
  final String? categoryId;
  final String? categoryName;

  const _ContentTypeGrid({
    required this.subject,
    this.categoryId,
    this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return OfflineAwareStreamBuilder<List<StudyMaterialModel>>(
      stream: FirestoreService.getStudyMaterialsStream(subject.id),
      loadingBuilder: (_) => _buildGrid(
        context,
        testCount: subject.testCount,
        materialCounts: null,
      ),
      // When the stream has data, compute per-type counts and show cards.
      dataBuilder: (context, materials, isStale) {
        final counts = <StudyMaterialType, int>{
          StudyMaterialType.previousPaper: 0,
          StudyMaterialType.notes: 0,
          StudyMaterialType.syllabus: 0,
        };
        for (final m in materials) {
          counts[m.type] = (counts[m.type] ?? 0) + 1;
        }
        return _buildGrid(
          context,
          testCount: subject.testCount,
          materialCounts: counts,
        );
      },
      // Offline / error → still show the Tests card (testCount is on the
      // subject model, available without a network call).
      offlineBuilder: (_, __) => _buildGrid(
        context,
        testCount: subject.testCount,
        materialCounts: null,
      ),
      errorBuilder: (_, __, ___) => _buildGrid(
        context,
        testCount: subject.testCount,
        materialCounts: null,
      ),
      emptyBuilder: (_, __) => _buildGrid(
        context,
        testCount: subject.testCount,
        materialCounts: {},
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context, {
    required int testCount,
    Map<StudyMaterialType, int>? materialCounts,
  }) {
    final cards = <_ContentTypeCardData>[];

    // Tests card — ALWAYS shown (every subject has at least seeded tests).
    cards.add(_ContentTypeCardData(
      emoji: '📝',
      label: 'Tests',
      count: testCount,
      color: AppTheme.primaryColor,
      onTap: () => _navigateToTests(context),
    ));

    // Previous Papers — only if count > 0
    final paperCount = materialCounts?[StudyMaterialType.previousPaper] ?? 0;
    if (paperCount > 0) {
      cards.add(_ContentTypeCardData(
        emoji: '📄',
        label: 'Previous Papers',
        count: paperCount,
        color: const Color(0xFF1565C0),
        onTap: () => _navigateToMaterials(
          context,
          StudyMaterialType.previousPaper,
        ),
      ));
    }

    // Study Notes — only if count > 0
    final noteCount = materialCounts?[StudyMaterialType.notes] ?? 0;
    if (noteCount > 0) {
      cards.add(_ContentTypeCardData(
        emoji: '📖',
        label: 'Study Notes',
        count: noteCount,
        color: const Color(0xFF388E3C),
        onTap: () => _navigateToMaterials(
          context,
          StudyMaterialType.notes,
        ),
      ));
    }

    // Syllabus — only if count > 0
    final syllabusCount = materialCounts?[StudyMaterialType.syllabus] ?? 0;
    if (syllabusCount > 0) {
      cards.add(_ContentTypeCardData(
        emoji: '📋',
        label: 'Syllabus',
        count: syllabusCount,
        color: const Color(0xFFF57C00),
        onTap: () => _navigateToMaterials(
          context,
          StudyMaterialType.syllabus,
        ),
      ));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) => _buildCard(context, cards[index]),
    );
  }

  Widget _buildCard(BuildContext context, _ContentTypeCardData data) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: data.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                data.color.withOpacity(0.1),
                data.color.withOpacity(0.03),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: data.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        data.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: data.color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${data.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                data.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                data.count == 1 ? '1 item' : '${data.count} items',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTests(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TestListScreen(
          subject: subject,
          categoryId: categoryId,
        ),
      ),
    );
  }

  void _navigateToMaterials(
    BuildContext context,
    StudyMaterialType type,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MaterialListScreen(
          subject: subject,
          type: type,
        ),
      ),
    );
  }
}

/// Simple data holder for a content-type card.
class _ContentTypeCardData {
  final String emoji;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  _ContentTypeCardData({
    required this.emoji,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });
}
