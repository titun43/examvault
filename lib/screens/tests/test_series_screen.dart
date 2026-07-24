// =============================================================================
// ExamVault - Test Series Screen (All Tests)
// =============================================================================
//
// PERFORMANCE ARCHITECTURE:
// This screen may render dozens of test cards. To keep both scrolling AND
// theme-toggle smooth, we apply these optimizations:
//
// 1. isDark is computed ONCE at the list level (in the StreamBuilder's
//    builder), then passed to each card as a constructor param. This avoids
//    N independent Theme.of(context) lookups (one per card).
//
// 2. All theme-dependent colors (including withOpacity() results) are
//    pre-computed in a _ThemeColors helper, built once per rebuild and shared
//    across all cards. withOpacity() is expensive (creates a new Color), so
//    calling it 5× per card × 30 cards = 150 allocations on every rebuild.
//    Pre-computing drops that to 5 allocations total.
//
// 3. The card shadow list is a top-level const (_kCardShadow) instead of
//    AppTheme.softShadow1 (which is a GETTER that allocates a new List every
//    access). 30 cards = 30 avoided list allocations per rebuild.
//
// 4. Each card is a separate StatelessWidget (_TestCard) wrapped in a
//    RepaintBoundary. This lets Flutter isolate painting — when one card
//    repaints, its neighbors don't. On theme toggle, all cards rebuild
//    (unavoidable — colors change), but the PAINTING phase is isolated per
//    card so the cost is bounded.
//
// 5. As many TextStyle/Widget objects as possible are const, so they're
//    shared across all card instances and never reallocated.
// =============================================================================

import 'package:flutter/material.dart';
import '../../models/test_model.dart';
import '../../models/subject_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../search/search_screen.dart';
import 'take_test_screen.dart';
import 'test_list_screen.dart';

// Pre-computed card shadow — const so it's allocated once at compile time,
// not per card per rebuild. (AppTheme.softShadow1 is a getter that allocates
// a new List<BoxShadow> on every access — fine for one-off use, expensive
// inside a list builder.)
const _kCardShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];

// Pre-computed opacity colors that don't depend on the theme mode.
// (Primary color is the same in light + dark mode, so these are constant.)
final _kPrimaryTint10 = AppTheme.primaryColor.withOpacity(0.1);
final _kPrimaryTint40 = AppTheme.primaryColor.withOpacity(0.4);

/// Pre-computed theme-dependent colors, built once per rebuild and shared
/// across all cards in the list. Avoids per-card withOpacity() calls.
class _ThemeColors {
  final bool isDark;
  final Color cardColor;
  final Color titleColor;
  final Color subtleTextColor;
  final Color borderColor;
  final Color footerBgColor;
  final Color emptyIconColor;
  final Color emptyTextColor;
  final Color subjectSubtitleColor;
  final Color trailingIconColor;

  const _ThemeColors({
    required this.isDark,
    required this.cardColor,
    required this.titleColor,
    required this.subtleTextColor,
    required this.borderColor,
    required this.footerBgColor,
    required this.emptyIconColor,
    required this.emptyTextColor,
    required this.subjectSubtitleColor,
    required this.trailingIconColor,
  });

  factory _ThemeColors.of(bool isDark) {
    return _ThemeColors(
      isDark: isDark,
      cardColor: isDark ? AppTheme.darkCardColor : Colors.white,
      titleColor: isDark ? Colors.white : const Color(0xFF1C1917),
      subtleTextColor:
          isDark ? Colors.white60 : const Color(0xFF6B7280),
      borderColor: isDark
          ? Colors.white.withOpacity(0.06)
          : AppTheme.cardBorderColor,
      footerBgColor: isDark
          ? Colors.white.withOpacity(0.03)
          : const Color(0xFFFAFAFA),
      emptyIconColor: isDark ? Colors.white30 : Colors.grey,
      emptyTextColor: isDark ? Colors.white60 : Colors.grey.shade600,
      subjectSubtitleColor:
          isDark ? Colors.white60 : Colors.grey.shade600,
      trailingIconColor: isDark ? Colors.white38 : Colors.grey.shade400,
    );
  }
}

class TestSeriesScreen extends StatelessWidget {
  const TestSeriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Test Series'),
          actions: [
            // Global search — available on every bottom-nav tab, not just Home.
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                );
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Mock'),
              Tab(text: 'Previous Year'),
              Tab(text: 'Daily Quiz'),
              Tab(text: 'Practice'),
              Tab(text: 'Subject-wise'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TestList(type: null),
            _TestList(type: TestType.mock),
            _TestList(type: TestType.previousYear),
            _TestList(type: TestType.dailyQuiz),
            _TestList(type: TestType.practice),
            _SubjectList(),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _TestList — one tab's worth of test cards. Streams tests by type.
// =============================================================================

class _TestList extends StatelessWidget {
  final TestType? type;
  const _TestList({this.type});

  @override
  Widget build(BuildContext context) {
    // Compute theme colors ONCE for the entire list, then share with every
    // card. This is the #1 perf win: avoids N × Theme.of(context) + N × 5
    // withOpacity() calls.
    final tc = _ThemeColors.of(
        Theme.of(context).brightness == Brightness.dark);

    return StreamBuilder<List<TestModel>>(
      stream: FirestoreService.getTestsStream(type: type, isPublished: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.quiz_outlined,
                    size: 64, color: tc.emptyIconColor),
                const SizedBox(height: 16),
                Text(
                  'No tests available',
                  style: TextStyle(color: tc.emptyTextColor),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          // Each card is wrapped in a RepaintBoundary by default
          // (addRepaintBoundaries: true), so off-screen cards don't repaint
          // when visible ones update.
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            return _TestCard(
              test: snapshot.data![index],
              tc: tc,
            );
          },
        );
      },
    );
  }
}

// =============================================================================
// _TestCard — the 4-row Testbook-style card for a single test.
// Extracted as a separate StatelessWidget so Flutter can optimize element
// diffing. Takes pre-computed _ThemeColors so it doesn't call Theme.of or
// withOpacity itself.
// =============================================================================

class _TestCard extends StatelessWidget {
  final TestModel test;
  final _ThemeColors tc;

  const _TestCard({required this.test, required this.tc});

  @override
  Widget build(BuildContext context) {
    // Access badge label + color (Row 1 left).
    final String accessLabel;
    final Color accessColor;
    final bool accessIsGradient;
    if (!test.isPaid) {
      accessLabel = 'FREE';
      accessColor = AppTheme.successColor;
      accessIsGradient = false;
    } else if (test.isPremium && test.price <= 0) {
      accessLabel = 'Premium';
      accessColor = AppTheme.accentColor;
      accessIsGradient = true;
    } else {
      accessLabel = '\u20b9${test.price}';
      accessColor = AppTheme.accentColor;
      accessIsGradient = false;
    }

    // CTA link label (Row 3 right).
    final String ctaLabel = !test.isPaid
        ? 'Start Now'
        : (test.isPremium && test.price <= 0
            ? 'Unlock'
            : 'Buy \u20b9${test.price}');
    final Color ctaColor =
        !test.isPaid ? AppTheme.primaryColor : AppTheme.accentColor;
    final IconData ctaIcon = !test.isPaid
        ? Icons.arrow_forward_rounded
        : (test.isPremium && test.price <= 0
            ? Icons.workspace_premium_rounded
            : Icons.shopping_cart_outlined);

    // Access badge tint — depends on accessColor which varies per test,
    // so compute once here (not 2× in the Container + border).
    final accessTint = accessColor.withOpacity(0.15);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: tc.cardColor,
        borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusLg)),
        boxShadow: _kCardShadow,
        border: Border.all(color: tc.borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusLg)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TakeTestScreen(test: test),
                ),
              );
            },
            borderRadius: const BorderRadius.all(Radius.circular(AppTheme.radiusLg)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== Top content block =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceLg,
                    AppTheme.spaceMd,
                    AppTheme.spaceLg,
                    AppTheme.spaceMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== ROW 1: Badges (left) + type tag (right) =====
                      Row(
                        children: [
                          // Access badge pill.
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceSm,
                              vertical: AppTheme.spaceXs,
                            ),
                            decoration: BoxDecoration(
                              gradient: accessIsGradient
                                  ? const LinearGradient(
                                      colors: AppTheme.accentGradientColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: accessIsGradient ? null : accessTint,
                              borderRadius: const BorderRadius.all(
                                  Radius.circular(AppTheme.radiusFull)),
                            ),
                            child: Text(
                              accessLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accessIsGradient
                                    ? Colors.white
                                    : accessColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceSm),
                          // Type pill (outlined, primary).
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceSm,
                              vertical: AppTheme.spaceXs,
                            ),
                            decoration: BoxDecoration(
                              color: _kPrimaryTint10,
                              borderRadius: const BorderRadius.all(
                                  Radius.circular(AppTheme.radiusFull)),
                              border: Border.all(
                                color: _kPrimaryTint40,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              _getTypeName(test.type),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Difficulty chip (right).
                          _buildDifficultyChip(test.difficulty),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceSm),

                      // ===== ROW 2: Title =====
                      Text(
                        test.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tc.titleColor,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.spaceSm),

                      // ===== ROW 3: Stats (left) + Start Now link (right) =====
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '${test.questionCount} Qs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: tc.subtleTextColor,
                                  ),
                                ),
                                _dotSeparator(tc.subtleTextColor),
                                Text(
                                  '${test.duration} min',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: tc.subtleTextColor,
                                  ),
                                ),
                                _dotSeparator(tc.subtleTextColor),
                                Text(
                                  '${test.totalMarks} marks',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: tc.subtleTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceSm),
                          // "Start Now →" link.
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TakeTestScreen(test: test),
                                ),
                              );
                            },
                            borderRadius: const BorderRadius.all(
                                Radius.circular(AppTheme.radiusSm)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceSm,
                                vertical: AppTheme.spaceXs,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    ctaLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: ctaColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(ctaIcon, size: 16, color: ctaColor),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ===== ROW 4: Footer bar =====
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLg,
                    vertical: AppTheme.spaceSm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: tc.footerBgColor,
                    border: Border(
                      top: BorderSide(color: tc.borderColor, width: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up_rounded,
                          size: 13, color: AppTheme.primaryColor),
                      const SizedBox(width: 3),
                      Text(
                        '${test.attemptCount} attempts',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMd),
                      const Icon(Icons.people_alt_outlined,
                          size: 13, color: AppTheme.primaryColor),
                      const SizedBox(width: 3),
                      const Text(
                        'All users',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.share_outlined,
                        size: 13,
                        color: AppTheme.successColor,
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        'Share',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Gray dot separator between stats.
  static Widget _dotSeparator(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '\u00b7',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  static Widget _buildDifficultyChip(TestDifficulty difficulty) {
    final color = difficulty == TestDifficulty.easy
        ? Colors.green
        : difficulty == TestDifficulty.medium
            ? Colors.orange
            : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        difficulty.name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static String _getTypeName(TestType type) {
    switch (type) {
      case TestType.mock:
        return 'MOCK TEST';
      case TestType.previousYear:
        return 'PREVIOUS YEAR';
      case TestType.dailyQuiz:
        return 'DAILY QUIZ';
      case TestType.practice:
        return 'PRACTICE';
      case TestType.subjectwise:
        return 'SUBJECT WISE';
    }
  }
}

// =============================================================================
// _SubjectList — the "Subject-wise" tab. Shows all subjects as tappable
// cards; tapping opens the test list for that subject.
// =============================================================================

class _SubjectList extends StatelessWidget {
  const _SubjectList();

  @override
  Widget build(BuildContext context) {
    final tc = _ThemeColors.of(
        Theme.of(context).brightness == Brightness.dark);

    return StreamBuilder<List<SubjectModel>>(
      stream: FirestoreService.getSubjectsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book, size: 64, color: tc.emptyIconColor),
                const SizedBox(height: 16),
                Text(
                  'No subjects available',
                  style: TextStyle(color: tc.emptyTextColor),
                ),
              ],
            ),
          );
        }
        // Sort by name for easy scanning.
        final subjects = List<SubjectModel>.from(snapshot.data!)
          ..sort((a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: subjects.length,
          itemBuilder: (context, index) {
            return _SubjectCard(subject: subjects[index], tc: tc);
          },
        );
      },
    );
  }
}

// =============================================================================
// _SubjectCard — a single subject row in the Subject-wise tab.
// =============================================================================

class _SubjectCard extends StatelessWidget {
  final SubjectModel subject;
  final _ThemeColors tc;

  const _SubjectCard({required this.subject, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: tc.cardColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _kPrimaryTint10,
          child: Text(
            subject.icon ?? '📘',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          subject.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: tc.titleColor,
          ),
        ),
        subtitle: Text(
          '${subject.testCount} ${subject.testCount == 1 ? 'Test' : 'Tests'}'
          '${subject.description != null && subject.description!.isNotEmpty ? ' · ${subject.description}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: tc.subjectSubtitleColor),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: tc.trailingIconColor,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              // Navigate DIRECTLY to TestListScreen (no intermediate hub).
              builder: (_) => TestListScreen(
                subject: subject,
                categoryId: subject.categoryId,
              ),
            ),
          );
        },
      ),
    );
  }
}
