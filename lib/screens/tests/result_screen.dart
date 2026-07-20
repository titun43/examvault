// =============================================================================
// ExamVault - Result Screen
// =============================================================================
//
// v2 MODERNIZATION (visual layer overhaul):
//   - Hero header replaced with a circular progress ring
//     (CircularPercentIndicator) showing the score percentage. Ring color
//     reflects performance: green (>=60%), orange (35-59%), red (<35%).
//     Header gradient is brand emerald (AppTheme.brandGradient).
//   - Inside the ring: "obtained/total" big and bold + percentage subtitle.
//   - Contextual message below the ring: result_excellent (>=80%),
//     result_good (>=60%), result_keepGoing (<60%). Bilingual via L10nText.
//   - "Share Result" icon button in the hero corner (share_plus).
//   - 3-card stats row: Correct (green check) / Wrong (red close) /
//     Skipped (grey dash). Each card: soft shadow, rounded, colored icon tile.
//   - Time-taken + Rank pills row (rank shown only if > 0).
//   - Action buttons: Retake Test (outlined) + Review Answers (filled,
//     scrolls to the review section via Scrollable.ensureVisible).
//   - Answer review section: each question is an expandable card with a
//     status-colored number badge, status chip, color-coded options
//     (correct=green, user-wrong=red), and an explanation box with
//     primaryColor tint + light-bulb icon. All question/option/explanation
//     text uses AppFonts.style so Assamese script renders correctly.
//   - All visible strings bilingual via tr() / L10nText.
//   - flutter_animate staggered entrance on hero, stats, pills, buttons,
//     and the review list.
//   - Design tokens (AppTheme.space*/radius*/softShadow*) used throughout.
//   - NO blue/indigo -- emerald primary, amber accent, semantic colors only.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../models/test_result_model.dart';
import '../../models/question_model.dart';
import '../../models/test_model.dart';
import '../../services/admob_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';

class ResultScreen extends StatefulWidget {
  final TestResultModel result;
  final List<QuestionModel> questions;
  final List<int> userAnswers;
  final TestModel? test; // optional -- needed for "Retake Test"

  const ResultScreen({
    super.key,
    required this.result,
    required this.questions,
    required this.userAnswers,
    this.test,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _reviewKey = GlobalKey();
  // Indices of question cards the user has expanded.
  final Set<int> _expanded = <int>{};

  TestResultModel get _result => widget.result;
  List<QuestionModel> get _questions => widget.questions;
  List<int> get _userAnswers => widget.userAnswers;

  /// Ring + accent color reflecting performance bands.
  Color get _ringColor {
    if (_result.percentage >= 60) return AppTheme.successColor;
    if (_result.percentage >= 35) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  /// l10n key for the contextual congratulations / encouragement message.
  String get _messageKey {
    if (_result.percentage >= 80) return 'result_excellent';
    if (_result.percentage >= 60) return 'result_good';
    return 'result_keepGoing';
  }

  /// "12m 30s" style formatting of the time-taken seconds value.
  String get _timeFormatted {
    final m = _result.timeTaken ~/ 60;
    final s = _result.timeTaken % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToReview() {
    final ctx = _reviewKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  Future<void> _shareResult() async {
    final lines = <String>[
      '📝 ${_result.testTitle}',
      'Score: ${_result.obtainedMarks}/${_result.totalMarks} '
          '(${_result.percentage.toStringAsFixed(1)}%)',
      '✅ Correct: ${_result.correctAnswers}  '
          '❌ Wrong: ${_result.wrongAnswers}  '
          '➖ Skipped: ${_result.unattempted}',
      '⏱ Time: $_timeFormatted',
    ];
    try {
      await Share.share(
        lines.join('\n'),
        subject: 'ExamVault — ${_result.testTitle}',
      );
    } catch (_) {
      // Non-fatal: silent on share failure.
    }
  }

  void _retake() {
    // Preserve original navigation: pop back so the user can restart the
    // test or navigate from the test list.
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ==================== HERO HEADER (score ring) ====================
              SliverToBoxAdapter(child: _buildHeroHeader()),
              // ==================== STATS ROW (3 cards) ====================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppTheme.spaceLg, AppTheme.spaceLg, AppTheme.spaceLg, 0),
                  child: _buildStatsRow(isDark),
                ),
              ),
              // ==================== TIME + RANK PILLS ====================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLg,
                      vertical: AppTheme.spaceMd),
                  child: _buildMetaPills(isDark),
                ),
              ),
              // ==================== ACTION BUTTONS ====================
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg,
                      AppTheme.spaceSm, AppTheme.spaceLg, AppTheme.spaceLg),
                  child: _buildActionButtons(),
                ),
              ),
              // ==================== ANSWER REVIEW SECTION ====================
              SliverToBoxAdapter(
                child: Padding(
                  key: _reviewKey,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLg),
                  child: _buildReviewHeader(isDark),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceLg),
                    child: _buildReviewCard(context, index, isDark),
                  )
                      .animate()
                      .fadeIn(
                        delay: (index * 50).clamp(0, 500).ms,
                        duration: 350.ms,
                      )
                      .slideY(begin: 0.06),
                  childCount: _questions.length,
                ),
              ),
              const SliverToBoxAdapter(
                  child: SizedBox(height: AppTheme.spaceXxl)),
            ],
          ),
          // Invisible trigger that shows the post-test interstitial ad after
          // this screen is fully built + a 2s delay. See _PostTestAdTrigger.
          const _PostTestAdTrigger(),
        ],
      ),
    );
  }

  // ==================== HERO HEADER ====================
  Widget _buildHeroHeader() {
    final clampedPercent =
        (_result.percentage / 100).clamp(0.0, 1.0).toDouble();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.brandGradient,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg,
              AppTheme.spaceSm, AppTheme.spaceLg, AppTheme.spaceXl),
          child: Column(
            children: [
              // Top row: back + title + share
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.maybePop(context),
                    tooltip: tr(context, 'back'),
                  ),
                  Expanded(
                    child: L10nText(
                      'result_testResult',
                      style: AppFonts.style(
                        size: 18,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded,
                        color: Colors.white),
                    onPressed: _shareResult,
                    tooltip: tr(context, 'result_share'),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceLg),
              // Score ring
              CircularPercentIndicator(
                radius: 90,
                lineWidth: 12,
                percent: clampedPercent,
                circularStrokeCap: CircularStrokeCap.round,
                progressColor: _ringColor,
                backgroundColor: Colors.white.withOpacity(0.18),
                animation: true,
                animationDuration: 900,
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${_result.obtainedMarks}/${_result.totalMarks}',
                      style: AppFonts.style(
                        size: 28,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_result.percentage.toStringAsFixed(1)}%',
                      style: AppFonts.style(
                        size: 14,
                        weight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.92),
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.88, 0.88)),
              const SizedBox(height: AppTheme.spaceMd),
              // Contextual message
              L10nText(
                _messageKey,
                style: AppFonts.style(
                  size: 18,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ).animate().fadeIn(delay: 250.ms),
              const SizedBox(height: AppTheme.spaceXs),
              L10nText(
                'result_score',
                style: AppFonts.style(
                  size: 12,
                  color: Colors.white.withOpacity(0.85),
                ),
              ).animate().fadeIn(delay: 320.ms),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== STATS ROW (3 cards) ====================
  Widget _buildStatsRow(bool isDark) {
    return Row(
      children: [
        _buildStatCard(
          icon: Icons.check_rounded,
          count: _result.correctAnswers,
          labelKey: 'result_correct',
          color: AppTheme.successColor,
          isDark: isDark,
        ),
        const SizedBox(width: AppTheme.spaceMd),
        _buildStatCard(
          icon: Icons.close_rounded,
          count: _result.wrongAnswers,
          labelKey: 'result_wrong',
          color: AppTheme.errorColor,
          isDark: isDark,
        ),
        const SizedBox(width: AppTheme.spaceMd),
        _buildStatCard(
          icon: Icons.remove_rounded,
          count: _result.unattempted,
          labelKey: 'result_skipped',
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          isDark: isDark,
        ),
      ],
    ).animate().fadeIn(delay: 380.ms, duration: 400.ms).slideY(begin: 0.08);
  }

  Widget _buildStatCard({
    required IconData icon,
    required int count,
    required String labelKey,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardColor : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.softShadow1,
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              '$count',
              style: AppFonts.style(
                size: 22,
                weight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            L10nText(
              labelKey,
              style: AppFonts.style(
                size: 11,
                weight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TIME + RANK PILLS ====================
  Widget _buildMetaPills(bool isDark) {
    final pills = <Widget>[
      _buildPill(
        icon: Icons.timer_rounded,
        value: _timeFormatted,
        labelKey: 'result_timeTaken',
        color: AppTheme.primaryColor,
        isDark: isDark,
      ),
    ];
    if (_result.rank > 0) {
      pills.add(const SizedBox(width: AppTheme.spaceMd));
      pills.add(_buildPill(
        icon: Icons.emoji_events_rounded,
        value: '#${_result.rank}',
        labelKey: 'result_rank',
        color: AppTheme.accentDarkColor,
        isDark: isDark,
      ));
    }
    return Row(children: pills)
        .animate()
        .fadeIn(delay: 440.ms, duration: 400.ms)
        .slideY(begin: 0.06);
  }

  Widget _buildPill({
    required IconData icon,
    required String value,
    required String labelKey,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceSm + 2,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: AppFonts.style(
                      size: 14,
                      weight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  L10nText(
                    labelKey,
                    style: AppFonts.style(
                      size: 10,
                      color:
                          isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTION BUTTONS ====================
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _retake,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: L10nText('result_retake'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _scrollToReview,
            icon: const Icon(Icons.menu_book_rounded, size: 18),
            label: L10nText('result_review'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  // ==================== REVIEW HEADER ====================
  Widget _buildReviewHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(
          top: AppTheme.spaceLg, bottom: AppTheme.spaceMd),
      child: Row(
        children: [
          L10nText(
            'result_answerReview',
            style: AppFonts.style(
              size: 18,
              weight: FontWeight.w700,
              color: isDark ? Colors.grey.shade50 : Colors.black87,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSm + 2, vertical: AppTheme.spaceXs),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              '${_questions.length}',
              style: AppFonts.style(
                size: 12,
                weight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 540.ms);
  }

  // ==================== REVIEW CARD (expandable) ====================
  Widget _buildReviewCard(BuildContext context, int index, bool isDark) {
    final question = _questions[index];
    final userAnswer =
        index < _userAnswers.length ? _userAnswers[index] : -1;
    final isCorrect = userAnswer == question.correctAnswerIndex;
    final isSkipped = userAnswer == -1;
    final isExpanded = _expanded.contains(index);

    final Color statusColor = isCorrect
        ? AppTheme.successColor
        : isSkipped
            ? (isDark ? Colors.grey.shade400 : Colors.grey.shade600)
            : AppTheme.errorColor;
    final String statusKey = isCorrect
        ? 'result_correct'
        : isSkipped
            ? 'result_skipped'
            : 'result_wrong';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softShadow1,
        border: Border.all(color: statusColor.withOpacity(0.18), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expanded.remove(index);
              } else {
                _expanded.add(index);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: badge + question + chevron
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Number badge (status-colored)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: AppFonts.style(
                            size: 13,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMd),
                    // Question text (AppFonts.style for Assamese fallback)
                    Expanded(
                      child: Text(
                        question.question,
                        style: AppFonts.style(
                          size: 14,
                          weight: FontWeight.w500,
                          height: 1.5,
                          color:
                              isDark ? Colors.grey.shade50 : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    // Chevron
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSm),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSm + 2,
                    vertical: AppTheme.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: L10nText(
                    statusKey,
                    style: AppFonts.style(
                      size: 11,
                      weight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                // Expandable detail (options + explanation)
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: isExpanded
                      ? _buildReviewDetail(
                          context, question, userAnswer, isDark)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewDetail(
    BuildContext context,
    QuestionModel question,
    int userAnswer,
    bool isDark,
  ) {
    final Color neutralBg =
        isDark ? Colors.grey.shade800 : Colors.grey.shade50;
    final Color neutralBorder =
        isDark ? Colors.grey.shade600 : Colors.grey.shade200;
    final Color optionTextColor =
        isDark ? Colors.grey.shade50 : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.spaceMd),
        // Options -- correct answer green, user's wrong answer red
        ...List.generate(question.options.length, (i) {
          final isCorrectAnswer = i == question.correctAnswerIndex;
          final isUserAnswer = i == userAnswer;
          final Color bgColor = isCorrectAnswer
              ? AppTheme.successColor.withOpacity(0.12)
              : isUserAnswer
                  ? AppTheme.errorColor.withOpacity(0.12)
                  : neutralBg;
          final Color borderColor = isCorrectAnswer
              ? AppTheme.successColor
              : isUserAnswer
                  ? AppTheme.errorColor
                  : neutralBorder;
          return Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCorrectAnswer
                        ? AppTheme.successColor
                        : isUserAnswer
                            ? AppTheme.errorColor
                            : (isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + i),
                      style: AppFonts.style(
                        size: 12,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                // Option text uses AppFonts.style for Assamese fallback
                Expanded(
                  child: Text(
                    question.options[i],
                    style: AppFonts.style(
                      size: 13,
                      color: optionTextColor,
                      height: 1.4,
                    ),
                  ),
                ),
                if (isCorrectAnswer)
                  const Icon(Icons.check_circle,
                      color: AppTheme.successColor, size: 18)
                else if (isUserAnswer)
                  const Icon(Icons.cancel,
                      color: AppTheme.errorColor, size: 18),
              ],
            ),
          );
        }),
        // Explanation box (primaryColor tint + light-bulb icon)
        if (question.explanation != null &&
            question.explanation!.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spaceSm),
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.18),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: AppTheme.spaceXs),
                    L10nText(
                      'result_explanation',
                      style: AppFonts.style(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSm),
                // Explanation text uses AppFonts.style for Assamese fallback
                Text(
                  question.explanation!,
                  style: AppFonts.style(
                    size: 13,
                    height: 1.5,
                    color: isDark ? Colors.grey.shade100 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// _PostTestAdTrigger — invisible widget that safely shows the interstitial
// ad after the ResultScreen is fully built and stable.
// =============================================================================
// WHY THIS EXISTS:
// Previously, AdMobService.showInterstitialAd() was called from
// TakeTestScreen._persistAndNavigate() IMMEDIATELY after Navigator
// .pushReplacement(...). That call was the #1 cause of the post-submit
// native crash: the Activity is mid-transition (test screen being replaced
// by result screen), and presenting a full-screen interstitial on top of a
// transitioning Activity can SIGSEGV below Dart's runZonedGuarded — the
// process is killed instantly ("app closes after test submit").
//
// FIX: this tiny StatefulWidget sits invisibly inside ResultScreen's build
// tree. In its initState it schedules the ad show via
// addPostFrameCallback (guarantees ResultScreen's first frame is painted)
// + a 2-second Future.delayed (guarantees the navigation transition is
// complete and the Activity is stable). Only then does it call
// AdMobService.showInterstitialAd(), which is now safe because the
// Activity is no longer mid-transition.
//
// The widget renders nothing (SizedBox.shrink) — it's purely a lifecycle
// hook for scheduling the ad show at a safe moment.
class _PostTestAdTrigger extends StatefulWidget {
  const _PostTestAdTrigger();

  @override
  State<_PostTestAdTrigger> createState() => _PostTestAdTriggerState();
}

class _PostTestAdTriggerState extends State<_PostTestAdTrigger> {
  @override
  void initState() {
    super.initState();

    // Schedule the ad show for AFTER this frame is painted, then wait an
    // additional 2 seconds so the navigation transition (pushReplacement)
    // is fully complete and the Activity is stable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        // Guard: if the user already navigated away from ResultScreen
        // (e.g. tapped "Home" or "Retake Test" within 2s), skip the ad
        // — showing it on top of a different screen would be jarring.
        if (!mounted) return;

        // Guard: only show if the AdMob SDK initialized successfully AND
        // an interstitial is actually preloaded. This prevents calling
        // .show() on a null/stale ad reference.
        if (!AdMobService.isInitialized) return;
        if (!AdMobService.isInterstitialReady) {
          // No ad preloaded yet — kick off a preload so the NEXT test's
          // ad is ready (the preload started in _loadQuestions may still
          // be in flight on a slow network).
          try {
            AdMobService.loadInterstitialAd();
          } catch (_) {}
          return;
        }

        try {
          AdMobService.showInterstitialAd();
        } catch (e) {
          // Non-fatal: a failed show is logged but never crashes the app.
          print('showInterstitialAd (post-test) failed (non-fatal): $e');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
