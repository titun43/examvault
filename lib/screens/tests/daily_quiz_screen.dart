// =============================================================================
// ExamVault - Daily Quiz Screen
// Fetches daily quizzes from Firestore (tests where type == dailyQuiz).
// The admin creates these from the admin panel (web or in-app) by selecting
// "Daily Quiz" as the test type.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../models/test_model.dart';
import '../../models/subject_model.dart';
import '../../services/category_preference_service.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/streak_helper.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/weekly_streak_indicator.dart';
import 'take_test_screen.dart';

class DailyQuizScreen extends StatefulWidget {
  const DailyQuizScreen({super.key});

  @override
  State<DailyQuizScreen> createState() => _DailyQuizScreenState();
}

class _DailyQuizScreenState extends State<DailyQuizScreen> {
  // Categories the user picked during onboarding / Profile > My Categories.
  // When set, daily quizzes are narrowed to those whose subject's parent
  // category is in this set. Falls back to all when the filtered list is empty.
  List<String> _preferredCategoryIds = [];
  // subjectId -> categoryId lookup map, built from a one-time fetch of all
  // subjects. Used to filter quizzes by their subject's parent category.
  Map<String, String> _subjectIdToCategoryId = const {};
  // AuthProvider reference for listening to preferred-category changes.
  AuthProvider? _auth;

  // Cached Firestore stream. Creating the stream inline inside build() is a
  // Flutter anti-pattern: every parent rebuild (e.g. theme toggle) hands the
  // StreamBuilder a BRAND-NEW stream object, so Flutter cancels the old
  // subscription and re-subscribes -> resets connection state to "waiting"
  // -> spinner flash. Cache it once in initState instead.
  late final Stream<List<TestModel>> _quizzesStream;

  @override
  void initState() {
    super.initState();
    // Cache the stream ONCE so theme toggles don't re-fetch from Firestore.
    _quizzesStream = FirestoreService.getTestsStream(
      type: TestType.dailyQuiz,
      isPublished: true,
    );
    _loadMeta();
    _loadPreferredCategoryIds();
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

  /// One-time fetch of all subjects to build the subjectId -> categoryId
  /// lookup map. Subjects don't change often, so a Future is fine here —
  /// the quizzes themselves still stream via the StreamBuilder below.
  Future<void> _loadMeta() async {
    try {
      final subs = await FirestoreService.getSubjects();
      final lookup = <String, String>{};
      for (final s in subs) {
        if (s.id.isNotEmpty && s.categoryId.isNotEmpty) {
          lookup[s.id] = s.categoryId;
        }
      }
      if (mounted) setState(() => _subjectIdToCategoryId = lookup);
    } catch (_) {
      // Non-fatal — filter just won't apply until subjects load.
    }
  }

  Future<void> _loadPreferredCategoryIds() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ids = await CategoryPreferenceService.getSelectedCategoryIds(auth.user);
    if (!mounted) return;
    if (_listEquals(ids, _preferredCategoryIds)) return;
    setState(() => _preferredCategoryIds = ids);
  }

  void _onAuthChanged() {
    if (!mounted) return;
    _loadPreferredCategoryIds();
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Quiz')),
      body: StreamBuilder<List<TestModel>>(
        // Cached in initState — see _quizzesStream field doc.
        stream: _quizzesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(context, isDark);
          }
          var quizzes = snapshot.data ?? [];
          // Filter by preferred categories (with fallback to all when the
          // filtered list is empty — never show an empty screen if there are
          // quizzes in other categories the user hasn't selected).
          if (_preferredCategoryIds.isNotEmpty &&
              _subjectIdToCategoryId.isNotEmpty) {
            final filtered = quizzes.where((t) {
              final catId = _subjectIdToCategoryId[t.subjectId];
              return catId != null && _preferredCategoryIds.contains(catId);
            }).toList();
            if (filtered.isNotEmpty) quizzes = filtered;
          }
          if (quizzes.isEmpty) {
            return _buildEmptyState(context, isDark);
          }

          final today = quizzes.first; // getTestsStream sorts by createdAt desc
          final previous = quizzes.skip(1).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Streak / motivational card — shows the user's actual current
                // streak + a 7-day weekly activity strip. Reads from
                // AuthProvider so it reflects the latest test submission.
                // Wrapped in a Consumer<AuthProvider> so ONLY this card
                // rebuilds when AuthProvider notifies (e.g. after a test
                // submission updates streak) — the parent State does NOT
                // rebuild, so the StreamBuilder above doesn't re-subscribe
                // and we avoid a spinner flash.
                Consumer<AuthProvider>(
                  builder: (ctx, auth, _) => _buildStreakCard(ctx, auth),
                ),
                const SizedBox(height: 24),
                // Today's Quiz
                Text(
                  "Today's Quiz",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey.shade50 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _DailyQuizCard(test: today, isFeatured: true),
                if (previous.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Previous Quizzes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey.shade50 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...previous.map(
                    (q) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DailyQuizCard(test: q, isFeatured: false),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds the streak / motivational card. Takes the [auth] as a parameter
  /// (instead of calling Provider.of<AuthProvider>(context) internally) so
  /// the ONLY context subscribed to AuthProvider changes is the Consumer at
  /// the call site — the parent _DailyQuizScreenState does NOT subscribe,
  /// which means AuthProvider notifies (streak updates, user-doc writes,
  /// etc.) do NOT trigger a full screen rebuild + stream re-subscription.
  Widget _buildStreakCard(BuildContext context, AuthProvider auth) {
    final user = auth.user;
    final storedStreak = user?.streak ?? 0;
    final lastActive = user?.lastActiveAt;
    final effectiveStreak = computeEffectiveStreak(storedStreak, lastActive);
    final message = streakMessage(effectiveStreak, lastActive);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Colors.white, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$effectiveStreak',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'day streak',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Weekly activity strip — Mon→Sun dots. Only the days we can prove
          // activity on are filled; the rest render as empty rings so the
          // user sees exactly which days they still need to cover.
          WeeklyStreakIndicator(
            lastActiveAt: lastActive,
            activeColor: Colors.white,
            inactiveColor: Colors.white38,
            labelColor: Colors.white70,
            dotSize: 30,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return const EmptyState(
      icon: Icons.calendar_today,
      l10nTitleKey: 'dailyQuiz_emptyTitle',
      l10nDescKey: 'dailyQuiz_emptyDesc',
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark) {
    return const EmptyState(
      icon: Icons.cloud_off,
      l10nTitleKey: 'dailyQuiz_errorTitle',
      l10nDescKey: 'dailyQuiz_errorDesc',
      iconColor: AppTheme.errorColor,
    );
  }
}

/// Card representing a single daily quiz. When tapped, navigates to
/// TakeTestScreen with the full test.
class _DailyQuizCard extends StatelessWidget {
  final TestModel test;
  final bool isFeatured; // true = "Today's Quiz" (featured accent color)

  const _DailyQuizCard({required this.test, required this.isFeatured});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1917);
    final subtleTextColor =
        isDark ? Colors.white60 : const Color(0xFF6B7280);
    final cardColor = isDark ? AppTheme.darkCardColor : Colors.white;
    final borderColor =
        isDark ? Colors.white.withOpacity(0.06) : AppTheme.cardBorderColor;
    final footerBgColor = isDark
        ? Colors.white.withOpacity(0.03)
        : const Color(0xFFFAFAFA);
    final accentColor =
        isFeatured ? AppTheme.accentColor : AppTheme.primaryColor;

    // Access badge (Row 1 left).
    final String accessLabel;
    final Color accessBadgeColor;
    final bool accessIsGradient;
    if (!test.isPaid) {
      accessLabel = 'FREE';
      accessBadgeColor = AppTheme.successColor;
      accessIsGradient = false;
    } else if (test.isPremium && test.price <= 0) {
      accessLabel = 'Premium';
      accessBadgeColor = AppTheme.accentColor;
      accessIsGradient = true;
    } else {
      accessLabel = '\u20b9${test.price}';
      accessBadgeColor = AppTheme.accentColor;
      accessIsGradient = false;
    }

    // CTA link label (Row 3 right).
    final String ctaLabel = !test.isPaid
        ? 'Start Now'
        : (test.isPremium && test.price <= 0
            ? 'Unlock'
            : 'Buy \u20b9${test.price}');

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
            onTap: () {
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
                      // ===== ROW 1: Badges (left) + "Live" tag (right) =====
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
                                  ? LinearGradient(
                                      colors:
                                          AppTheme.accentGradientColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: accessIsGradient
                                  ? null
                                  : accessBadgeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusFull),
                            ),
                            child: Text(
                              accessLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accessIsGradient
                                    ? Colors.white
                                    : accessBadgeColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceSm),
                          // "Daily Quiz" type pill (outlined).
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceSm,
                              vertical: AppTheme.spaceXs,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusFull),
                              border: Border.all(
                                color: accentColor.withOpacity(0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'DAILY QUIZ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Lightning bolt icon for daily quiz identity.
                          Icon(
                            Icons.bolt_rounded,
                            size: 18,
                            color: accentColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceSm),

                      // ===== ROW 2: Title =====
                      Text(
                        test.title,
                        style: TextStyle(
                          fontSize: isFeatured ? 17 : 16,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (test.instructions != null &&
                          test.instructions!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          test.instructions!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: subtleTextColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppTheme.spaceSm),

                      // ===== ROW 3: Stats (left) + Start Now link (right) =====
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment:
                                  WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '${test.questionCount} Qs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: subtleTextColor,
                                  ),
                                ),
                                _dotSeparator(subtleTextColor),
                                Text(
                                  '${test.duration} min',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: subtleTextColor,
                                  ),
                                ),
                                _dotSeparator(subtleTextColor),
                                Text(
                                  '${test.totalMarks} marks',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: subtleTextColor,
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
                                  builder: (_) =>
                                      TakeTestScreen(test: test),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm),
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
                                      color: accentColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: accentColor,
                                  ),
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
                    color: footerBgColor,
                    border: Border(
                      top: BorderSide(color: borderColor, width: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up_rounded,
                          size: 13, color: AppTheme.primaryColor),
                      const SizedBox(width: 3),
                      Text(
                        '${test.attemptCount} attempts',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMd),
                      if (test.negativeMarking) ...[
                        Icon(Icons.warning_amber_rounded,
                            size: 13, color: AppTheme.warningColor),
                        const SizedBox(width: 3),
                        Text(
                          'Neg marking',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warningColor,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceMd),
                      ],
                      const Spacer(),
                      Icon(
                        Icons.share_outlined,
                        size: 13,
                        color: AppTheme.successColor,
                      ),
                      const SizedBox(width: 3),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Gray dot separator between stats.
  Widget _dotSeparator(Color color) {
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
}
