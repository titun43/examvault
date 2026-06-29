// =============================================================================
// ExamVault - Test Series Screen (All Tests)
// =============================================================================

import 'package:flutter/material.dart';
import '../../models/test_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import 'test_list_screen.dart';

class TestSeriesScreen extends StatelessWidget {
  const TestSeriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Test Series'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Mock'),
              Tab(text: 'Previous Year'),
              Tab(text: 'Daily Quiz'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTestList(context, null),
            _buildTestList(context, TestType.mock),
            _buildTestList(context, TestType.previousYear),
            _buildTestList(context, TestType.dailyQuiz),
          ],
        ),
      ),
    );
  }

  Widget _buildTestList(BuildContext context, TestType? type) {
    return StreamBuilder<List<TestModel>>(
      stream: FirestoreService.getTestsStream(type: type, isPublished: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No tests available'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final test = snapshot.data![index];
            return _buildTestCard(context, test);
          },
        );
      },
    );
  }

  Widget _buildTestCard(BuildContext context, TestModel test) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTypeColor(test.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getTypeName(test.type),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getTypeColor(test.type),
                    ),
                  ),
                ),
                const Spacer(),
                if (test.isPremium)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, size: 12, color: AppTheme.accentColor),
                        SizedBox(width: 4),
                        Text(
                          'Premium',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              test.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(Icons.help_outline, '${test.questionCount} Qs'),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.timer_outlined, '${test.duration} min'),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.star_outline, '${test.totalMarks} marks'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDifficultyChip(test.difficulty),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TestListScreen(testId: test.id),
                      ),
                    );
                  },
                  child: const Text('Start'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildDifficultyChip(TestDifficulty difficulty) {
    final color = difficulty == TestDifficulty.easy
        ? Colors.green
        : difficulty == TestDifficulty.medium
            ? Colors.orange
            : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
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

  Color _getTypeColor(TestType type) {
    switch (type) {
      case TestType.mock:
        return AppTheme.primaryColor;
      case TestType.previousYear:
        return AppTheme.accentColor;
      case TestType.dailyQuiz:
        return Colors.purple;
      case TestType.practice:
        return Colors.green;
      case TestType.subjectwise:
        return Colors.teal;
    }
  }

  String _getTypeName(TestType type) {
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
