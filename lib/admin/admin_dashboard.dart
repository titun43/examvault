// =============================================================================
// ExamVault - Admin Dashboard
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'screens/admin_home_screen.dart';
import 'screens/admin_categories_screen.dart';
import 'screens/admin_tests_screen.dart';
import 'screens/admin_previous_papers_screen.dart';
import 'screens/admin_questions_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/admin_payments_screen.dart';
import 'screens/admin_analytics_screen.dart';
import 'screens/admin_announcements_screen.dart';
import 'screens/admin_upcoming_exams_screen.dart';
import 'screens/admin_banners_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final _screens = [
    const AdminHomeScreen(),
    const AdminCategoriesScreen(),
    const AdminTestsScreen(),
    const AdminPreviousPapersScreen(),
    const AdminQuestionsScreen(),
    const AdminAnnouncementsScreen(),
    const AdminUpcomingExamsScreen(),
    const AdminBannersScreen(),
    const AdminUsersScreen(),
    const AdminPaymentsScreen(),
    const AdminAnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
              ),
            ),
            child: Column(
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(24),
                  child: const Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'ExamVault',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
                // Menu Items
                Expanded(
                  child: ListView.builder(
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      final item = _menuItems[index];
                      final isSelected = _selectedIndex == index;
                      return ListTile(
                        leading: Icon(
                          item['icon'] as IconData,
                          color: isSelected ? AppTheme.primaryColor : Colors.white70,
                        ),
                        title: Text(
                          item['title'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor: AppTheme.primaryColor.withOpacity(0.2),
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }

  final _menuItems = [
    {'title': 'Dashboard', 'icon': Icons.dashboard},
    {'title': 'Categories', 'icon': Icons.category},
    {'title': 'Tests', 'icon': Icons.quiz},
    {'title': 'Previous Papers', 'icon': Icons.history_edu},
    {'title': 'Questions', 'icon': Icons.question_answer},
    {'title': 'Announcements', 'icon': Icons.campaign},
    {'title': 'Upcoming Exams', 'icon': Icons.event_available},
    {'title': 'Banners', 'icon': Icons.view_carousel},
    {'title': 'Users', 'icon': Icons.people},
    {'title': 'Payments', 'icon': Icons.payment},
    {'title': 'Analytics', 'icon': Icons.analytics},
  ];
}
