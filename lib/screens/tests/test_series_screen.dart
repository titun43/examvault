// =============================================================================
// ExamVault - Test Series Screen (All Tests)
// =============================================================================

import 'package:flutter/material.dart';
import '../../models/test_model.dart';
import '../../models/subject_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../search/search_screen.dart';
import 'take_test_screen.dart';
import '../home/subject_detail_screen.dart';

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
        body: TabBarView(
          children: [
            _buildTestList(context, null),
            _buildTestList(context, TestType.mock),
            _buildTestList(context, TestType.previousYear),
            _buildTestList(context, TestType.dailyQuiz),
            _buildTestList(context, TestType.practice),
            _buildSubjectList(context),
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
            // Test meta info — wraps cleanly on small screens (was a Row that
            // overflowed/truncated the marks text on narrow devices).
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildInfoChip(Icons.help_outline, '${test.questionCount} Qs'),
                _buildInfoChip(Icons.timer_outlined, '${test.duration} min'),
                _buildInfoChip(Icons.star_outline, '${test.totalMarks} marks'),
                _buildInfoChip(
                    Icons.trending_up, '${test.attemptCount} attempts'),
                _buildDifficultyChip(test.difficulty),
              ],
            ),
            const SizedBox(height: 16),
            // Full-width Start button — no truncation, easy to tap.
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate directly to TakeTestScreen so categoryId is
                  // resolved inside TakeTestScreen via getSubjectById +
                  // resolveCategoryId — fixing the "Go Premium" bug for
                  // exam-pack holders who arrive through Test Series.
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TakeTestScreen(test: test),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('Start Test'),
              ),
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

  /// Subject-wise tab: shows ALL subjects (not tests of type=subjectwise).
  /// Tapping a subject opens its test list. This makes the tab genuinely
  /// "subject-wise" browsing and ensures it's never empty as long as
  /// subjects exist. The previous implementation filtered tests by
  /// type=='subjectwise' which no test ever had (seed uses mock/practice),
  /// so the tab always showed "No tests available".
  Widget _buildSubjectList(BuildContext context) {
    return StreamBuilder<List<SubjectModel>>(
      stream: FirestoreService.getSubjectsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No subjects available'),
              ],
            ),
          );
        }
        // Sort by name for easy scanning.
        final subjects = List<SubjectModel>.from(snapshot.data!)
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: subjects.length,
          itemBuilder: (context, index) {
            final subject = subjects[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    subject.icon ?? '📘',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                title: Text(
                  subject.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${subject.testCount} ${subject.testCount == 1 ? 'Test' : 'Tests'}'
                  '${subject.description != null && subject.description!.isNotEmpty ? ' · ${subject.description}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // Navigate to SubjectDetailScreen (content hub) so
                      // the user can choose between Tests, Papers, Notes,
                      // Syllabus. The subject's categoryId is used as the
                      // authoritative category id (may be name/slug in edge
                      // cases — acceptable here since this tab is not the
                      // primary exam-pack purchase entry point).
                      builder: (_) => SubjectDetailScreen(
                        subject: subject,
                        categoryId: subject.categoryId,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
