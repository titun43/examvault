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
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/streak_helper.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/weekly_streak_indicator.dart';
import 'test_instructions_screen.dart';

class DailyQuizScreen extends StatelessWidget {
  const DailyQuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Quiz')),
      body: StreamBuilder<List<TestModel>>(
        stream: FirestoreService.getTestsStream(
          type: TestType.dailyQuiz,
          isPublished: true,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(context, isDark);
          }
          final quizzes = snapshot.data ?? [];
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
                _buildStreakCard(context),
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

  Widget _buildStreakCard(BuildContext context) {
    // Read the live user from AuthProvider so the card reflects the latest
    // test submission (streak + lastActiveAt update after each test).
    final auth = Provider.of<AuthProvider>(context);
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
  final bool isFeatured; // true = "Today's Quiz" (larger, "Start Quiz" CTA)

  const _DailyQuizCard({required this.test, required this.isFeatured});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey.shade50 : Colors.black87;
    final subtitleColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final mutedColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: AppTheme.accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    test.title,
                    style: TextStyle(
                      fontSize: isFeatured ? 16 : 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                if (test.isPremium)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 12, color: AppTheme.accentColor),
                        SizedBox(width: 2),
                        Text(
                          'PREMIUM',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _metaChip(Icons.help_outline, '${test.questionCount} Qs', mutedColor),
                _metaChip(Icons.timer, '${test.duration} min', mutedColor),
                _metaChip(
                    Icons.star_border, '${test.totalMarks} marks', mutedColor),
                _metaChip(Icons.trending_up, '${test.attemptCount} attempts',
                    mutedColor),
              ],
            ),
            if (test.instructions != null &&
                test.instructions!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                test.instructions!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: subtitleColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TestInstructionsScreen(test: test),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isFeatured ? AppTheme.accentColor : AppTheme.primaryColor,
                ),
                child: Text(isFeatured ? 'Start Quiz' : 'Start'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
}
