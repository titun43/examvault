// ExamVault - Test History Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../models/test_result_model.dart';
import '../../services/firestore_service.dart';

class TestHistoryScreen extends StatelessWidget {
  const TestHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context).user?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Test History')),
      body: StreamBuilder<List<TestResultModel>>(
        stream: FirestoreService.getUserResultsStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No tests attempted yet'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final result = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(result.testTitle),
                  subtitle: Text('${result.correctAnswers}/${result.totalQuestions} correct • ${result.percentage.toStringAsFixed(1)}%'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: result.isPassed ? AppTheme.successColor : AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      result.isPassed ? 'PASSED' : 'FAILED',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
