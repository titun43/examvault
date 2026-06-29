// =============================================================================
// ExamVault - Admin Dashboard (sidebar nav with all 10 management sections)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/admin_categories_screen.dart';
import 'screens/admin_tests_screen.dart';
import 'screens/admin_questions_screen.dart';
import 'screens/admin_users_screen.dart';
import 'screens/admin_payments_screen.dart';
import 'screens/admin_analytics_screen.dart';
import 'screens/admin_announcements_screen.dart';
import 'screens/admin_current_affairs_screen.dart';
import 'screens/admin_upcoming_exams_screen.dart';
import '../widgets/scrolling_announcement_banner.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final _screens = const [
    AdminHomeScreen(),
    AdminCategoriesScreen(),
    AdminTestsScreen(),
    AdminQuestionsScreen(),
    AdminUsersScreen(),
    AdminPaymentsScreen(),
    AdminAnnouncementsScreen(),
    AdminCurrentAffairsScreen(),
    AdminUpcomingExamsScreen(),
    AdminAnalyticsScreen(),
  ];

  final _menuItems = [
    {'title': 'Dashboard', 'icon': Icons.dashboard},
    {'title': 'Categories', 'icon': Icons.category},
    {'title': 'Tests', 'icon': Icons.quiz},
    {'title': 'Questions', 'icon': Icons.question_answer},
    {'title': 'Users', 'icon': Icons.people},
    {'title': 'Payments', 'icon': Icons.payment},
    {'title': 'Announcements', 'icon': Icons.campaign},
    {'title': 'Current Affairs', 'icon': Icons.newspaper},
    {'title': 'Upcoming Exams', 'icon': Icons.event},
    {'title': 'Analytics', 'icon': Icons.analytics},
  ];

  Future<void> _logout() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: isWide ? 250 : 220,
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
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.white70,
                        ),
                        title: Text(
                          item['title'] as String,
                          style: TextStyle(
                            color:
                                isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor:
                            AppTheme.primaryColor.withOpacity(0.2),
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                      );
                    },
                  ),
                ),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: _logout,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Scrolling announcement banner at top
                const ScrollingAnnouncementBanner(isAdmin: true),
                // Selected admin screen
                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
