// =============================================================================
// ExamVault - All Free Tests Screen
// =============================================================================
// Shows EVERY published test that is FREE (price == 0 && isPremium == false).
// This is the destination of the "All Free Tests" button on the Home screen.
//
// CATEGORY FILTER:
// A horizontal chip row at the top lets the user filter free tests by exam
// category (Railway, SSC, UPSC, etc.). "All" shows every free test across
// all categories. Filtering is done client-side using a subjectId -> categoryId
// lookup map built from a one-time fetch of all subjects.
//
// Admins mark a test as free by leaving the "Premium (paid users only)"
// toggle OFF and the price at 0 in the admin test form — no extra flag is
// needed (TestModel.isPaid already captures this).
//
// CARD DESIGN:
// Mirrors the 4-row Testbook-style card used on test_list_screen,
// test_series_screen, and daily_quiz_screen for visual consistency. The only
// difference: every card here shows a fixed green "FREE" badge in Row 1
// (since every test on this screen is free).
//
// PERFORMANCE:
// This screen may render dozens of cards. To keep scrolling smooth:
//   - No per-card entrance animation (cascading delays make scroll janky).
//   - No Hero wrapper on the title (Hero is for screen transitions, not
//     flat lists — it adds a Material wrapper + transition bookkeeping).
//   - Each card is wrapped in a RepaintBoundary so cards off-screen don't
//     repaint when the visible ones update.
//   - const constructors used wherever possible.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import '../../l10n/app_localizations.dart';
import '../../models/category_model.dart';
import '../../models/subject_model.dart';
import '../../models/test_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';
import '../../utils/localized_content.dart';
import '../../widgets/empty_state.dart';
import 'take_test_screen.dart';

class FreeTestsScreen extends StatefulWidget {
  const FreeTestsScreen({super.key});

  @override
  State<FreeTestsScreen> createState() => _FreeTestsScreenState();
}

class _FreeTestsScreenState extends State<FreeTestsScreen> {
  // Category filter state.
  // null = "All" (show free tests from every category).
  String? _selectedCategoryId;

  // Categories for the filter chip row. Empty until the one-time fetch lands.
  List<CategoryModel> _categories = const [];

  // subjectId -> categoryId lookup map, built from a one-time fetch of all
  // subjects. Used to filter tests by their subject's parent category.
  Map<String, String> _subjectIdToCategoryId = const {};

  // True while categories + subjects are being fetched (one-time, in
  // initState). The filter chip row shows a tiny placeholder while loading.
  bool _loadingMeta = true;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  /// One-time fetch of all categories + subjects. These don't change often,
  /// so a Future (not a Stream) is fine here — the tests themselves still
  /// stream via the StreamBuilder below.
  Future<void> _loadMeta() async {
    try {
      final results = await Future.wait([
        FirestoreService.getCategories(),
        FirestoreService.getSubjects(),
      ]);
      final cats = results[0] as List<CategoryModel>;
      final subs = results[1] as List<SubjectModel>;

      final lookup = <String, String>{};
      for (final s in subs) {
        if (s.id.isNotEmpty && s.categoryId.isNotEmpty) {
          lookup[s.id] = s.categoryId;
        }
      }

      if (mounted) {
        setState(() {
          _categories = cats;
          _subjectIdToCategoryId = lookup;
          _loadingMeta = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingMeta = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: L10nText('free_tests_title'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ===== Sticky filter chip row (top) =====
          _buildFilterChips(context, isDark),
          // ===== Divider between chips and list =====
          Divider(
            height: 1,
            thickness: 0.8,
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : const Color(0xFFE5E7EB),
          ),
          // ===== Test list (fills remaining space) =====
          Expanded(
            child: StreamBuilder<List<TestModel>>(
              // Pull every published test; we filter for free ones client-side
              // to avoid needing a composite Firestore index.
              stream: FirestoreService.getTestsStream(isPublished: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerList(isDark);
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.error_outline_rounded,
                    titleText: 'Something went wrong',
                    descText: '${snapshot.error}',
                  );
                }

                // FREE = !isPaid = (price == 0 && !isPremium)
                var freeTests = (snapshot.data ?? const [])
                    .where((t) => !t.isPaid)
                    .toList();

                // Apply category filter (client-side via subject lookup).
                if (_selectedCategoryId != null) {
                  freeTests = freeTests.where((t) {
                    final catId = _subjectIdToCategoryId[t.subjectId];
                    return catId == _selectedCategoryId;
                  }).toList();
                }

                if (freeTests.isEmpty) {
                  // Different empty message depending on whether a category
                  // filter is active.
                  return EmptyState(
                    icon: Icons.card_giftcard_rounded,
                    l10nTitleKey: _selectedCategoryId != null
                        ? 'free_tests_no_in_category'
                        : 'free_tests_empty',
                    iconColor: AppTheme.successColor,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Count indicator: "N free tests" — helps the user see how
                    // many results are in the current filter selection.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spaceLg,
                        AppTheme.spaceSm,
                        AppTheme.spaceLg,
                        0,
                      ),
                      child: Text(
                        '${freeTests.length} ${tr(context, 'free_tests_count')}',
                        style: AppFonts.style(
                          size: 12,
                          weight: FontWeight.w600,
                          color: isDark ? Colors.white50 : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.spaceLg),
                        // addRepaintBoundary is true by default, but we make it
                        // explicit — each card is its own repaint boundary so
                        // off-screen cards don't repaint when visible ones update.
                        addRepaintBoundary: true,
                        itemCount: freeTests.length,
                        itemBuilder: (context, index) {
                          return _FreeTestCard(test: freeTests[index]);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // FILTER CHIPS — horizontal scrollable row of category chips at the top.
  // "All" is always first; categories follow in their natural order.
  // ===========================================================================
  Widget _buildFilterChips(BuildContext context, bool isDark) {
    // While categories are loading, show a slim placeholder row so the layout
    // doesn't jump when the chips arrive.
    if (_loadingMeta) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: RepaintBoundary(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLg,
        vertical: AppTheme.spaceSm + 2,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip(
              context: context,
              label: tr(context, 'free_tests_all'),
              isSelected: _selectedCategoryId == null,
              isDark: isDark,
              onTap: () => setState(() => _selectedCategoryId = null),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            for (final cat in _categories) ...[
              _buildChip(
                context: context,
                label: lc(context, cat.name, cat.nameAs),
                isSelected: _selectedCategoryId == cat.id,
                isDark: isDark,
                onTap: () => setState(() => _selectedCategoryId = cat.id),
              ),
              const SizedBox(width: AppTheme.spaceSm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd + 2,
          vertical: AppTheme.spaceSm + 2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : (isDark ? AppTheme.darkCardColor : Colors.white),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.grey.shade300),
            width: 1.2,
          ),
          boxShadow: isSelected ? AppTheme.softShadow1 : null,
        ),
        child: Text(
          label,
          style: AppFonts.style(
            size: 12,
            weight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF44403C)),
          ),
        ),
      ),
    );
  }

  // Skeleton placeholder while the Firestore stream is loading. Matches the
  // 4-row card shape so the layout doesn't jump when real cards arrive.
  Widget _buildShimmerList(bool isDark) {
    final baseColor = isDark ? Colors.white12 : Colors.black12;
    final highlightColor =
        isDark ? Colors.white24 : Colors.black.withOpacity(0.05);
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        itemBuilder: (context, _) => Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.cardBorderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 44, height: 16, color: Colors.white),
                        const Spacer(),
                        Container(width: 60, height: 12, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Container(
                        width: double.infinity, height: 16, color: Colors.white),
                    const SizedBox(height: AppTheme.spaceXs),
                    Container(width: 180, height: 16, color: Colors.white),
                    const SizedBox(height: AppTheme.spaceSm),
                    Row(
                      children: [
                        Container(width: 140, height: 12, color: Colors.white),
                        const Spacer(),
                        Container(width: 60, height: 14, color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                height: 36,
                width: double.infinity,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _FreeTestCard — the 4-row Testbook-style card for a single free test.
//
// PERFORMANCE NOTES:
//   - No flutter_animate entrance animation. The previous version used
//     `.animate().fadeIn(delay: (index * 50).ms)` on every card, which caused
//     cascading delays (card #30 had a 1500ms delay) and made scrolling feel
//     sluggish. Removed entirely.
//   - No Hero wrapper on the title. Hero is for screen-to-screen transitions
//     and adds a Material wrapper + transition bookkeeping that is wasted in
//     a flat list. The title is now a plain Text.
//   - The card is wrapped in a RepaintBoundary by the ListView.builder
//     (addRepaintBoundary: true) so off-screen cards don't repaint.
// =============================================================================

class _FreeTestCard extends StatelessWidget {
  final TestModel test;

  const _FreeTestCard({required this.test});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkCardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1917);
    final subtleTextColor =
        isDark ? Colors.white60 : const Color(0xFF6B7280);
    final borderColor =
        isDark ? Colors.white.withOpacity(0.06) : AppTheme.cardBorderColor;
    final footerBgColor =
        isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFFAFAFA);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softShadow1,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // Whole card is tappable — Testbook-style.
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TakeTestScreen(test: test),
                ),
              );
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== Top content block (padding) =====
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
                      // ===== ROW 1: Badges =====
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: AppTheme.spaceSm,
                              runSpacing: AppTheme.spaceXs,
                              children: _buildBadges(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceSm),

                      // ===== ROW 2: Title (plain Text — no Hero for perf) =====
                      Text(
                        test.title,
                        style: AppFonts.style(
                          size: 16,
                          weight: FontWeight.w700,
                          color: titleColor,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTheme.spaceSm),

                      // ===== ROW 3: Stats (left) + Start Now link (right) =====
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '${test.questionCount} ${tr(context, 'test_questions')}',
                                  style: AppFonts.style(
                                    size: 12,
                                    weight: FontWeight.w500,
                                    color: subtleTextColor,
                                  ),
                                ),
                                _dotSeparator(subtleTextColor),
                                Text(
                                  '${test.duration} ${tr(context, 'test_duration')}',
                                  style: AppFonts.style(
                                    size: 12,
                                    weight: FontWeight.w500,
                                    color: subtleTextColor,
                                  ),
                                ),
                                _dotSeparator(subtleTextColor),
                                Text(
                                  '${test.totalMarks} ${tr(context, 'test_marks')}',
                                  style: AppFonts.style(
                                    size: 12,
                                    weight: FontWeight.w500,
                                    color: subtleTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceSm),
                          _buildStartNowLink(context),
                        ],
                      ),
                    ],
                  ),
                ),

                // ===== ROW 4: Footer bar (type + EN + neg-marking + share) =====
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLg,
                    vertical: AppTheme.spaceSm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: footerBgColor,
                    border: Border(
                      top: BorderSide(color: borderColor, width: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.book_outlined,
                          size: 13, color: AppTheme.primaryColor),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          _typeLabel(context),
                          style: AppFonts.style(
                            size: 11,
                            weight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMd),
                      Icon(Icons.language_rounded,
                          size: 13, color: AppTheme.primaryColor),
                      const SizedBox(width: 3),
                      Text(
                        'EN',
                        style: AppFonts.style(
                          size: 11,
                          weight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMd),
                      if (test.negativeMarking) ...[
                        Icon(Icons.warning_amber_rounded,
                            size: 13, color: AppTheme.warningColor),
                        const SizedBox(width: 3),
                        Text(
                          tr(context, 'test_negativeMarking'),
                          style: AppFonts.style(
                            size: 11,
                            weight: FontWeight.w600,
                            color: AppTheme.warningColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: AppTheme.spaceMd),
                      ],
                      const Spacer(),
                      _ShareButton(test: test),
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

  /// Gray dot separator used between stats in Row 3.
  Widget _dotSeparator(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '\u00b7',
        style: AppFonts.style(
          size: 14,
          weight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  /// Row 1 badges — FREE (always green, fixed) + test-type pill (outlined).
  /// Every test on this screen is free, so the access badge is always FREE.
  List<Widget> _buildBadges(BuildContext context) {
    final badges = <Widget>[];

    // FREE — green filled pill (always, since this screen only shows free tests).
    badges.add(_pill(
      context: context,
      label: tr(context, 'free'),
      color: AppTheme.successColor,
    ));

    // Test-type pill (outlined, blue).
    final typeLabel = _typeLabel(context);
    if (typeLabel.isNotEmpty) {
      badges.add(_pill(
        context: context,
        label: typeLabel,
        color: AppTheme.primaryColor,
        outlined: true,
      ));
    }

    // Year pill (outlined) — for previous-year papers.
    if (test.year != null && test.year! > 0) {
      badges.add(_pill(
        context: context,
        label: '${test.year}',
        color: AppTheme.primaryColor,
        outlined: true,
      ));
    }

    return badges;
  }

  /// Resolves the test type to a localized short label for the type pill.
  String _typeLabel(BuildContext context) {
    switch (test.type) {
      case TestType.mock:
        return tr(context, 'test_mock');
      case TestType.previousYear:
        return tr(context, 'test_previousYear');
      case TestType.dailyQuiz:
        return tr(context, 'daily_quiz_title');
      case TestType.practice:
        return 'Practice';
      case TestType.subjectwise:
        return 'Subject-wise';
    }
  }

  /// Row 3 compact "Start Now ->" link. Testbook-style: blue text link with a
  /// right-arrow, NOT a full-width filled button. Always "Start Now" here
  /// because every test on this screen is free (no purchase flow needed).
  Widget _buildStartNowLink(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TakeTestScreen(test: test),
          ),
        );
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSm,
          vertical: AppTheme.spaceXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(context, 'startNow'),
              style: AppFonts.style(
                size: 13,
                weight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Compact pill helper (mirrors the one on test_list_screen for consistency).
  Widget _pill({
    required BuildContext context,
    required String label,
    Color? color,
    bool outlined = false,
  }) {
    final Color bg =
        outlined ? color!.withOpacity(0.1) : color!.withOpacity(0.15);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: outlined
            ? Border.all(color: color.withOpacity(0.4), width: 0.8)
            : null,
      ),
      child: Text(
        label,
        style: AppFonts.style(
          size: 10,
          weight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// =============================================================================
// _ShareButton — opens the system share sheet with the test title + app promo.
// (Mirrors the same widget on test_list_screen for visual consistency.)
// =============================================================================

class _ShareButton extends StatelessWidget {
  final TestModel test;
  const _ShareButton({required this.test});

  Future<void> _share() async {
    final text =
        '${test.title}\n\nCheck out this free test on ExamVault — mock tests, '
        'previous year papers & daily quizzes for Assam exams.';
    try {
      await Share.share(text);
    } catch (_) {
      // Silently ignore share failures — non-critical action.
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _share,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceXs,
          vertical: AppTheme.spaceXs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.share_outlined,
              size: 13,
              color: AppTheme.successColor,
            ),
            SizedBox(width: 3),
            Text(
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
    );
  }
}
