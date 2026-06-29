// =============================================================================
// ExamVault - Test List Screen (Tests in a category OR all tests) — offline
// =============================================================================

import 'package:flutter/material.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import 'take_test_screen.dart';

class TestListScreen extends StatelessWidget {
  final String? categoryId;
  final String title;

  const TestListScreen({
    super.key,
    this.categoryId,
    this.title = 'Tests',
  });

  @override
  Widget build(BuildContext context) {
    final tests = categoryId == null
        ? LocalDataService.getTests()
        : LocalDataService.testsByCategory(categoryId!);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: tests.isEmpty
          ? const Center(child: Text('No tests available'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tests.length,
              itemBuilder: (context, index) =>
                  _buildTestCard(context, tests[index]),
            ),
    );
  }

  Widget _buildTestCard(BuildContext context, LocalTest test) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TakeTestScreen(test: test)),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      test.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!test.isFree)
                    const Icon(Icons.workspace_premium,
                        color: AppTheme.accentColor, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfo(
                      Icons.help_outline, '${test.totalQuestions} Questions'),
                  const SizedBox(width: 16),
                  _buildInfo(Icons.timer, '${test.durationMinutes} min'),
                  const SizedBox(width: 16),
                  _buildInfo(Icons.star, '${test.totalMarks} marks'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfo(
                    test.isFree ? Icons.lock_open : Icons.lock,
                    test.isFree ? 'Free' : 'Premium',
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => TakeTestScreen(test: test)),
                      ),
                      child: const Text('Start Test'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
