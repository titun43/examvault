// =============================================================================
// ExamVault - Result Screen
// =============================================================================

import 'package:flutter/material.dart';
import '../../models/test_result_model.dart';
import '../../models/question_model.dart';
import '../../theme/app_theme.dart';

class ResultScreen extends StatelessWidget {
  final TestResultModel result;
  final List<QuestionModel> questions;
  final List<int> userAnswers;

  const ResultScreen({
    super.key,
    required this.result,
    required this.questions,
    required this.userAnswers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Result'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
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
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Solutions & Explanations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(questions.length, (index) {
              return _buildSolutionCard(index);
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

  Widget _buildSolutionCard(int index) {
    final question = questions[index];
    final userAnswer = userAnswers[index];
    final isCorrect = userAnswer == question.correctAnswerIndex;

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
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.question,
              style: const TextStyle(fontSize: 14),
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
                          : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCorrectAnswer
                        ? AppTheme.successColor
                        : isUserAnswer
                            ? AppTheme.errorColor
                            : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${String.fromCharCode(65 + i)}.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(question.options[i])),
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
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: AppTheme.infoColor, size: 18),
                        SizedBox(width: 8),
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
                    Text(question.explanation!),
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
