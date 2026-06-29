// =============================================================================
// ExamVault - Test History Screen (offline)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';

class TestHistoryScreen extends StatelessWidget {
  const TestHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = Provider.of<AuthProvider>(context).user?.id ?? '';
    final results = LocalDataService.resultsByUser(userId);

    return Scaffold(
      appBar: AppBar(title: const Text('Test History')),
      body: results.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No tests attempted yet'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final r = results[index];
                final pct = r.total > 0 ? (r.score / r.total) * 100 : 0.0;
                final isPassed = pct >= 40;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(r.testTitle),
                    subtitle: Text(
                        '${r.score}/${r.total} correct • ${pct.toStringAsFixed(1)}%'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPassed
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPassed ? 'PASSED' : 'FAILED',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
