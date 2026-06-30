// =============================================================================
// ExamVault - Test List Screen (Tests in a subject OR Test details)
// =============================================================================

import 'package:flutter/material.dart';
import '../../models/subject_model.dart';
import '../../models/test_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import 'take_test_screen.dart';

class TestListScreen extends StatelessWidget {
  final SubjectModel? subject;
  final String? testId;

  const TestListScreen({
    super.key,
    this.subject,
    this.testId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(subject?.name ?? 'Tests'),
      ),
      body: StreamBuilder<List<TestModel>>(
        stream: FirestoreService.getTestsStream(
          subjectId: subject?.id,
          isPublished: true,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load tests.\nPlease check your connection and retry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tests available'));
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
      ),
    );
  }

  Widget _buildTestCard(BuildContext context, TestModel test) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TakeTestScreen(test: test),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + premium badge — title wraps, badge stays fixed width
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  if (test.isPremium)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.workspace_premium, color: AppTheme.accentColor, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Test meta info — wraps cleanly on small screens
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildInfo(Icons.help_outline, '${test.questionCount} Questions'),
                  _buildInfo(Icons.timer, '${test.duration} min'),
                  _buildInfo(Icons.star, '${test.totalMarks} marks'),
                  _buildInfo(Icons.trending_up, '${test.attemptCount} attempts'),
                ],
              ),
              const SizedBox(height: 16),
              // Full-width Start Test button — no truncation, easy to tap
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
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
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
