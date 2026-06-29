// =============================================================================
// ExamVault - Admin Home Screen (Dashboard with stats)
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/firestore_service.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: FirestoreService.getDashboardStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Error loading stats'));
          }
          final stats = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: _statCards.length,
            itemBuilder: (context, index) {
              final card = _statCards[index];
              return _buildStatCard(
                card['title'] as String,
                stats[card['key']]?.toString() ?? '0',
                card['icon'] as IconData,
                card['color'] as Color,
              );
            },
          );
        },
      ),
    );
  }

  final _statCards = [
    {'title': 'Total Users', 'key': 'totalUsers', 'icon': Icons.people, 'color': AppTheme.primaryColor},
    {'title': 'Premium Users', 'key': 'premiumUsers', 'icon': Icons.workspace_premium, 'color': AppTheme.accentColor},
    {'title': 'Total Tests', 'key': 'totalTests', 'icon': Icons.quiz, 'color': Colors.purple},
    {'title': 'Total Questions', 'key': 'totalQuestions', 'icon': Icons.question_answer, 'color': Colors.teal},
    {'title': 'Total Attempts', 'key': 'totalAttempts', 'icon': Icons.assessment, 'color': Colors.green},
    {'title': 'Total Payments', 'key': 'totalPayments', 'icon': Icons.payment, 'color': Colors.red},
  ];

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
