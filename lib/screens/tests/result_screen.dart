// =============================================================================
// ExamVault - Result Screen
// =============================================================================

import 'package:flutter/material.dart';
import '../../models/test_result_model.dart';
import '../../models/question_model.dart';
import '../../models/test_model.dart';
import '../../services/admob_service.dart';
import '../../theme/app_theme.dart';

class ResultScreen extends StatelessWidget {
  final TestResultModel result;
  final List<QuestionModel> questions;
  final List<int> userAnswers;
  final TestModel? test; // optional — needed for "Retake Test"

  const ResultScreen({
    super.key,
    required this.result,
    required this.questions,
    required this.userAnswers,
    this.test,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Result'),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // The actual result content.
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
            // Score Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: result.isPassed ? AppTheme.primaryGradient : AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Icon(
                    result.isPassed ? Icons.celebration : Icons.sentiment_dissatisfied,
                    color: Colors.white,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    result.isPassed ? 'Congratulations!' : 'Keep Trying!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${result.percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'You scored ${result.obtainedMarks} out of ${result.totalMarks}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Stats Grid
            Row(
              children: [
                _buildStatCard(
                  'Correct',
                  result.correctAnswers.toString(),
                  AppTheme.successColor,
                  Icons.check_circle,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Wrong',
                  result.wrongAnswers.toString(),
                  AppTheme.errorColor,
                  Icons.cancel,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard(
                  'Unattempted',
                  result.unattempted.toString(),
                  Colors.grey,
                  Icons.remove_circle,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Accuracy',
                  '${result.accuracy.toStringAsFixed(1)}%',
                  AppTheme.infoColor,
                  Icons.gps_fixed,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Time taken
            Card(
              child: ListTile(
                leading: const Icon(Icons.timer, color: AppTheme.primaryColor),
                title: const Text('Time Taken'),
                trailing: Text(
                  '${result.timeTaken ~/ 60}:${(result.timeTaken % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Solutions
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Solutions & Explanations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.grey.shade50 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(questions.length, (index) {
              return _buildSolutionCard(context, index);
            }),
            const SizedBox(height: 24),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    child: const Text('Home'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Retake Test'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      // Invisible trigger that shows the post-test interstitial ad after
      // this screen is fully built + a 2s delay. See _PostTestAdTrigger docs.
      const _PostTestAdTrigger(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolutionCard(BuildContext context, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final question = questions[index];
    final userAnswer = userAnswers[index];
    final isCorrect = userAnswer == question.correctAnswerIndex;

    // Theme-aware neutral colors so the "default" option (not correct, not
    // user-selected) is readable in both light and dark mode. Previously
    // this used Colors.grey.shade50 which is near-invisible on a dark card.
    final Color neutralBg = isDark ? Colors.grey.shade800 : Colors.grey.shade50;
    final Color neutralBorder = isDark ? Colors.grey.shade600 : Colors.grey.shade200;
    final Color optionTextColor = isDark ? Colors.grey.shade50 : Colors.black87;
    final Color questionTextColor = isDark ? Colors.grey.shade50 : Colors.black87;
    final Color labelTextColor = isDark ? Colors.grey.shade100 : Colors.black87;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? AppTheme.successColor
                        : userAnswer == -1
                            ? Colors.grey
                            : AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isCorrect
                        ? Icons.check
                        : userAnswer == -1
                            ? Icons.remove
                            : Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Question ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: labelTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.question,
              style: TextStyle(fontSize: 14, color: questionTextColor),
            ),
            const SizedBox(height: 12),
            // Show options
            ...List.generate(question.options.length, (i) {
              final isCorrectAnswer = i == question.correctAnswerIndex;
              final isUserAnswer = i == userAnswer;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCorrectAnswer
                      ? AppTheme.successColor.withOpacity(0.1)
                      : isUserAnswer
                          ? AppTheme.errorColor.withOpacity(0.1)
                          : neutralBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCorrectAnswer
                        ? AppTheme.successColor
                        : isUserAnswer
                            ? AppTheme.errorColor
                            : neutralBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${String.fromCharCode(65 + i)}.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: optionTextColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        question.options[i],
                        style: TextStyle(color: optionTextColor),
                      ),
                    ),
                    if (isCorrectAnswer)
                      const Icon(Icons.check_circle, color: AppTheme.successColor, size: 18)
                    else if (isUserAnswer)
                      const Icon(Icons.cancel, color: AppTheme.errorColor, size: 18),
                  ],
                ),
              );
            }),
            if (question.explanation != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb, color: AppTheme.infoColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Explanation',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.infoColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question.explanation!,
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade100 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
