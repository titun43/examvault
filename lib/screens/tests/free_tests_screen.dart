// =============================================================================
// ExamVault - All Free Tests Screen
// =============================================================================
// Shows EVERY published test that is FREE (price == 0 && isPremium == false),
// regardless of subject/category. This is the destination of the "All Free
// Tests" button on the Home screen — a single, flat, scannable list of every
// free test in the app so a user on a budget can find them all in one place.
//
// Admins mark a test as free by leaving the "Premium (paid users only)"
// toggle OFF and the price at 0 in the admin test form — no extra flag is
// needed (TestModel.isPaid already captures this).
//
// Card design mirrors the 4-row Testbook-style card used on the
// test_list_screen, test_series_screen, and daily_quiz_screen for visual
// consistency. The only difference: every card here shows a fixed green
// "FREE" badge in Row 1 (since every test on this screen is free).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import '../../l10n/app_localizations.dart';
import '../../models/test_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';
import '../../widgets/empty_state.dart';
import 'take_test_screen.dart';

class FreeTestsScreen extends StatelessWidget {
  const FreeTestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: L10nText('free_tests_title'),
        elevation: 0,
      ),
      body: StreamBuilder<List<TestModel>>(
        // Pull every published test; we filter for free ones client-side to
        // avoid needing a composite Firestore index (matches the strategy
        // used by getTestsStream).
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
          final freeTests = (snapshot.data ?? const [])
              .where((t) => !t.isPaid)
              .toList();

          if (freeTests.isEmpty) {
            return EmptyState(
              icon: Icons.card_giftcard_rounded,
              l10nTitleKey: 'free_tests_empty',
              iconColor: AppTheme.successColor,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            itemCount: freeTests.length,
            itemBuilder: (context, index) {
              return _FreeTestCard(
                test: freeTests[index],
                index: index,
              );
            },
          );
        },
      ),
    );
  }

  // Skeleton placeholder while the Firestore stream is loading. Matches the
  // 4-row card shape so the layout doesn't jump when real cards arrive.
  Widget _buildShimmerList(bool isDark) {
    final baseColor = isDark ? Colors.white12 : Colors.black12;
    final highlightColor = isDark ? Colors.white24 : Colors.black.withOpacity(0.05);
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
                        Container(
                          width: 44,
                          height: 16,
                          color: Colors.white,
                        ),
                        const Spacer(),
                        Container(
                          width: 60,
                          height: 12,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Container(
                      width: double.infinity,
                      height: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(height: AppTheme.spaceXs),
                    Container(
                      width: 180,
                      height: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Row(
                      children: [
                        Container(
                          width: 140,
                          height: 12,
                          color: Colors.white,
                        ),
                        const Spacer(),
                        Container(
                          width: 60,
                          height: 14,
                          color: Colors.white,
                        ),
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
// =============================================================================

class _FreeTestCard extends StatelessWidget {
  final TestModel test;
  final int index;

  const _FreeTestCard({required this.test, required this.index});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkCardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1917);
    final subtleTextColor =
        isDark ? Colors.white60 : const Color(0xFF6B7280);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.06)
        : AppTheme.cardBorderColor;
    final footerBgColor = isDark
        ? Colors.white.withOpacity(0.03)
        : const Color(0xFFFAFAFA);

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
                      // ===== ROW 1: Badges (left) + type pill (right) =====
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: dual badges — FREE (always) + type pill.
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

                      // ===== ROW 2: Title (Hero, 2 lines) =====
                      Hero(
                        tag: 'test-title-${test.id}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
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
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSm),

                      // ===== ROW 3: Stats (left) + Start Now link (right) =====
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Stats inline: Qs · mins · marks (gray, dot-separated).
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
                          // "Start Now →" blue link (Testbook-style compact CTA).
                          // All tests here are free, so this always says "Start Now".
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
                      // Test-type tag (book icon + type label).
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
                      // Language indicator.
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
                      // Negative-marking warning (if applicable).
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
                      // Share button (green text + icon, Testbook-style).
                      _ShareButton(test: test),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 50).ms, duration: 400.ms)
        .slideY(begin: 0.06);
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

  /// Row 3 compact "Start Now →" link. Testbook-style: blue text link with a
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
            Icon(
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
          children: [
            Icon(
              Icons.share_outlined,
              size: 13,
              color: AppTheme.successColor,
            ),
            const SizedBox(width: 3),
            Text(
              'Share',
              style: AppFonts.style(
                size: 11,
                weight: FontWeight.w700,
                color: AppTheme.successColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
