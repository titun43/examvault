// =============================================================================
// ExamVault - Admin Home Screen (Dashboard with stats) — offline
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/local_data_service.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/home/main_navigation.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _stats = LocalDataService.dashboardStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.visibility),
            tooltip: 'Preview as Student',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MainNavigation()),
              );
            },
          ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, Admin!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Manage all app content from here. Changes reflect instantly in the user app.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Stats grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: _statCards.length,
              itemBuilder: (context, index) {
                final card = _statCards[index];
                return _buildStatCard(
                  card['title'] as String,
                  _stats[card['key']]?.toString() ?? '0',
                  card['icon'] as IconData,
                  card['color'] as Color,
                );
              },
            ),
            const SizedBox(height: 20),
            // Quick info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'How A-Z Control Works',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '1. Add/Edit Categories, Tests, Questions from the sidebar\n'
                      '2. All changes are saved locally on the device\n'
                      '3. Users see your updates immediately in their app\n'
                      '4. Tap the eye icon above to preview the student app',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _statCards => [
        {'title': 'Total Users', 'key': 'totalUsers', 'icon': Icons.people, 'color': AppTheme.primaryColor},
        {'title': 'Premium Users', 'key': 'premiumUsers', 'icon': Icons.workspace_premium, 'color': AppTheme.accentColor},
        {'title': 'Total Tests', 'key': 'totalTests', 'icon': Icons.quiz, 'color': Colors.purple},
        {'title': 'Total Questions', 'key': 'totalQuestions', 'icon': Icons.question_answer, 'color': Colors.teal},
        {'title': 'Revenue (₹)', 'key': 'totalRevenue', 'icon': Icons.currency_rupee, 'color': Colors.green},
        {'title': 'Categories', 'key': 'totalCategories', 'icon': Icons.category, 'color': Colors.orange},
        {'title': 'Payments', 'key': 'totalPayments', 'icon': Icons.payment, 'color': Colors.red},
        {'title': 'Announcements', 'key': 'totalAnnouncements', 'icon': Icons.campaign, 'color': Colors.blue},
        {'title': 'Upcoming Exams', 'key': 'totalUpcomingExams', 'icon': Icons.event, 'color': Colors.indigo},
      ];

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
