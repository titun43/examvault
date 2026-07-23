// =============================================================================
// ExamVault - Subject Detail Screen (Content Hub) — Modernized v3
// =============================================================================
// This is the HUB screen that appears when a user taps a subject from the
// Category Detail screen. It shows:
//
//   1. A category-themed hero header with the subject icon, name, and a
//      category chip — the gradient matches the exam category (ADRE → orange,
//      APSC → violet, TET → pink, etc.) so every subject feels connected to
//      its exam.
//   2. A prominent "Start a Mock Test" quick-start CTA — the most common
//      action a student takes on this screen, now one tap away.
//   3. A grid of CONTENT TYPE CARDS:
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
//   card disappears. Empty content types are simply not shown.
//
// v3 CHANGES (modernization):
//   - Title is now the subject NAME (was wrongly hardcoded "Study Material").
//   - Hero gradient is per-category via AppTheme.gradientFor() (was always
//     primaryColor → primaryDarkColor).
//   - All content-type card colors come from the theme palette — NO hardcoded
//     blue (#1565C0) anywhere. Respects the project "no blue/indigo" rule.
//   - All visible labels use the bilingual l10n layer (tr() / L10nText) so
//     Assamese users see অসমীয়া text.
//   - Added a quick-start CTA card for the most common action.
//   - Grid cards redesigned: icon on top, label, colored count — no redundant
//     count pill + "N items" text duplication. Cleaner Material 3 look with
//     soft shadows instead of harsh elevation.
//   - Subtle entrance animations via flutter_animate.
//   - Design tokens (AppTheme.space*/radius*/softShadow*) used throughout.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../l10n/app_localizations.dart';
import '../../models/study_material_model.dart';
import '../../models/subject_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';
import '../../utils/localized_content.dart';
import '../../widgets/connectivity_banner.dart';
import '../../widgets/offline_aware_stream_builder.dart';
import '../tests/test_list_screen.dart';
import '../study_materials/material_list_screen.dart';

class SubjectDetailScreen extends StatefulWidget {
  final SubjectModel subject;
  // The authoritative category Firestore id — forwarded to TestListScreen
  // so the server-side access check (exam pack) uses the real id, not the
  // subject's possibly-name/slug categoryId.
  final String? categoryId;
  final String? categoryName;
  // Bilingual Assamese form of [categoryName] — passed by the caller so the
  // hero header's category chip can be localized via lc(). The English
  // [categoryName] is still used for AppTheme.gradientFor() lookups.
  final String? categoryNameAs;

  const SubjectDetailScreen({
    super.key,
    required this.subject,
    this.categoryId,
    this.categoryName,
    this.categoryNameAs,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    // Per-category gradient — gives each exam its own signature look.
    final categoryGradient = AppTheme.gradientFor(widget.categoryName);
    // Localized display strings (computed once to avoid repeated Provider
    // lookups inside this build).
    final localizedName = lc(context, subject.name, subject.nameAs);
    final localizedDescription =
        lc(context, subject.description ?? '', subject.descriptionAs);
    final localizedCategoryName = widget.categoryName == null
        ? null
        : lc(context, widget.categoryName!, widget.categoryNameAs);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ==================== HERO HEADER ====================
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: categoryGradient.first,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: categoryGradient,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppTheme.spaceLg, AppTheme.spaceXl, AppTheme.spaceLg, AppTheme.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Category chip (top of hero)
                        if (widget.categoryName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceSm + 4, vertical: AppTheme.spaceXs + 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25), width: 1),
                            ),
                            child: Text(
                              localizedCategoryName!.toUpperCase(),
                              style: AppFonts.style(
                                size: 10,
                                weight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.15),
                        if (widget.categoryName != null) const SizedBox(height: AppTheme.spaceSm),

                        // Subject name + icon
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Subject icon — wrapped in Hero so it receives
                            // the flying icon from CategoryDetailScreen's
                            // subject card (tag: 'subject-icon-<id>').
                            Hero(
                              tag: 'subject-icon-${subject.id}',
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    subject.icon ?? '📚',
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceMd),
                            Expanded(
                              child: Text(
                                localizedName,
                                style: AppFonts.style(
                                  size: 26,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.15,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(delay: 100.ms, duration: 450.ms)
                            .slideY(begin: 0.12),

                        // Description
                        if (subject.description != null &&
                            subject.description!.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.spaceMd),
                          Text(
                            localizedDescription,
                            style: AppFonts.style(
                                size: 13, color: Colors.white.withValues(alpha: 0.92), height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                              .animate()
                              .fadeIn(delay: 220.ms, duration: 450.ms),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ==================== CONNECTIVITY BANNER ====================
          SliverToBoxAdapter(
            child: Column(
              children: const [ConnectivityBanner()],
            ),
          ),

          // ==================== CONTENT SECTION ====================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header — "Content" / "সামগ্ৰী"
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      L10nText(
                        'subject_contentTypes',
                        style: AppFonts.style(
                          size: 20,
                          weight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (subject.testCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceSm + 2, vertical: AppTheme.spaceXs),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text(
                            '${subject.testCount} ${tr(context, 'subject_tests')}',
                            style: AppFonts.style(
                              size: 11,
                              weight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ).animate().fadeIn(delay: 280.ms),
                  const SizedBox(height: AppTheme.spaceXs),
                  L10nText(
                    'subject_browseContent',
                    style: AppFonts.style(size: 13, color: Colors.grey[600]),
                  ).animate().fadeIn(delay: 320.ms),
                  const SizedBox(height: AppTheme.spaceXl),

                  // Quick-start CTA — most common action, one tap away
                  if (subject.testCount > 0)
                    _QuickStartCta(
                      subject: subject,
                      categoryId: widget.categoryId,
                      gradient: categoryGradient,
                    )
                        .animate()
                        .fadeIn(delay: 360.ms, duration: 450.ms)
                        .slideY(begin: 0.06),
                  if (subject.testCount > 0) const SizedBox(height: AppTheme.spaceXl),

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

// =============================================================================
// QUICK-START CTA — "Start a Mock Test" prominent button card
// =============================================================================
/// A gradient call-to-action card that takes the user straight to the test
/// list. Uses the category gradient so it visually ties the subject to its
/// exam. Shown only when the subject has at least one test.
class _QuickStartCta extends StatelessWidget {
  final SubjectModel subject;
  final String? categoryId;
  final List<Color> gradient;

  const _QuickStartCta({
    required this.subject,
    required this.categoryId,
    required this.gradient,
  });

  void _navigate(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        onTap: () => _navigate(context),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: AppTheme.softShadow2,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      L10nText(
                        'subject_startMock',
                        style: AppFonts.style(
                            size: 17, weight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${subject.testCount} ${tr(context, 'subject_tests')} • ${tr(context, 'startNow')}',
                        style: AppFonts.style(size: 12, color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CONTENT TYPE GRID — real-time stream of study materials
// =============================================================================
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
      labelKey: 'subject_tests',
      count: testCount,
      color: AppTheme.primaryColor,
      onTap: () => _navigateToTests(context),
    ));

    // Previous Papers — only if count > 0. Violet (NOT blue).
    final paperCount = materialCounts?[StudyMaterialType.previousPaper] ?? 0;
    if (paperCount > 0) {
      cards.add(_ContentTypeCardData(
        emoji: '📄',
        labelKey: 'subject_previousPapers',
        count: paperCount,
        color: const Color(0xFF7C3AED), // Violet 600
        onTap: () => _navigateToMaterials(context, StudyMaterialType.previousPaper),
      ));
    }

    // Study Notes — only if count > 0. Green from theme.
    final noteCount = materialCounts?[StudyMaterialType.notes] ?? 0;
    if (noteCount > 0) {
      cards.add(_ContentTypeCardData(
        emoji: '📖',
        labelKey: 'subject_studyNotes',
        count: noteCount,
        color: AppTheme.successColor,
        onTap: () => _navigateToMaterials(context, StudyMaterialType.notes),
      ));
    }

    // Syllabus — only if count > 0. Amber from theme.
    final syllabusCount = materialCounts?[StudyMaterialType.syllabus] ?? 0;
    if (syllabusCount > 0) {
      cards.add(_ContentTypeCardData(
        emoji: '📋',
        labelKey: 'subject_syllabus',
        count: syllabusCount,
        color: AppTheme.accentDarkColor,
        onTap: () => _navigateToMaterials(context, StudyMaterialType.syllabus),
      ));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.25, // wider, less cramped than old 1.1
        crossAxisSpacing: AppTheme.spaceMd,
        mainAxisSpacing: AppTheme.spaceMd,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) => _buildCard(context, cards[index])
          .animate()
          .fadeIn(delay: (400 + index * 80).ms, duration: 400.ms)
          .slideY(begin: 0.08),
    );
  }

  Widget _buildCard(BuildContext context, _ContentTypeCardData data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: data.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardColor : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppTheme.softShadow1,
            border: Border.all(color: data.color.withValues(alpha: 0.1), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon tile
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Center(
                    child: Text(data.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const Spacer(),
                // Label (bilingual)
                L10nText(
                  data.labelKey,
                  style: AppFonts.style(
                    size: 15,
                    weight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Count (colored to match the card accent — no redundant pill)
                Text(
                  data.count == 1
                      ? '1 ${tr(context, 'subject_item')}'
                      : '${data.count} ${tr(context, 'subject_items')}',
                  style: AppFonts.style(
                    size: 12,
                    weight: FontWeight.w600,
                    color: data.color,
                  ),
                ),
              ],
            ),
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

  void _navigateToMaterials(BuildContext context, StudyMaterialType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        // Issue #27: pass the resolved categoryName so MaterialListScreen's
        // hero gradient matches the exam category (ADRE/APSC/...) instead of
        // silently falling back to brand emerald because it was handed a
        // Firestore doc id / slug.
        builder: (_) => MaterialListScreen(
          subject: subject,
          type: type,
          categoryName: categoryName,
        ),
      ),
    );
  }
}

/// Simple data holder for a content-type card.
class _ContentTypeCardData {
  final String emoji;
  final String labelKey; // l10n key, e.g. 'subject_tests'
  final int count;
  final Color color;
  final VoidCallback onTap;

  _ContentTypeCardData({
    required this.emoji,
    required this.labelKey,
    required this.count,
    required this.color,
    required this.onTap,
  });
}
