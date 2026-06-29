// =============================================================================
// ExamVault - Admin Home Screen (Dashboard with stats) — offline
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/local_data_service.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = LocalDataService.dashboardStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await auth.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: GridView.builder(
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
      ),
    );
  }

  List<Map<String, dynamic>> get _statCards => [
        {
          'title': 'Total Users',
          'key': 'totalUsers',
          'icon': Icons.people,
          'color': AppTheme.primaryColor
        },
        {
          'title': 'Premium Users',
          'key': 'premiumUsers',
          'icon': Icons.workspace_premium,
          'color': AppTheme.accentColor
        },
        {
          'title': 'Total Tests',
          'key': 'totalTests',
          'icon': Icons.quiz,
          'color': Colors.purple
        },
        {
          'title': 'Total Questions',
          'key': 'totalQuestions',
          'icon': Icons.question_answer,
          'color': Colors.teal
        },
        {
          'title': 'Revenue (₹)',
          'key': 'totalRevenue',
          'icon': Icons.currency_rupee,
          'color': Colors.green
        },
        {
          'title': 'Categories',
          'key': 'totalCategories',
          'icon': Icons.category,
          'color': Colors.orange
        },
        {
          'title': 'Payments',
          'key': 'totalPayments',
          'icon': Icons.payment,
          'color': Colors.red
        },
        {
          'title': 'Announcements',
          'key': 'totalAnnouncements',
          'icon': Icons.campaign,
          'color': Colors.blue
        },
        {
          'title': 'Current Affairs',
          'key': 'totalCurrentAffairs',
          'icon': Icons.newspaper,
          'color': Colors.indigo
        },
      ];

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
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
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
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
