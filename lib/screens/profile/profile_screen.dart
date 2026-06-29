// =============================================================================
// ExamVault - Profile Screen (offline, uses LocalDataService)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/local_data_service.dart';
import '../auth/login_screen.dart';
import '../premium/premium_screen.dart';
import '../current_affairs/current_affairs_screen.dart';
import 'settings_screen.dart';
import 'test_history_screen.dart';
import 'bookmarks_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final results = user == null
        ? <LocalTestResult>[]
        : LocalDataService.resultsByUser(user.id);
    final testsAttempted = results.length;
    final totalScore = results.fold<int>(0, (s, r) => s + r.score);
    final totalMax = results.fold<int>(0, (s, r) => s + r.total);
    final avgPct = totalMax > 0 ? (totalScore / totalMax) * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: user?.photoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              user!.photoUrl!,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person,
                                  size: 50, color: AppTheme.primaryColor),
                            ),
                          )
                        : const Icon(Icons.person,
                            size: 50, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user?.name ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (user?.isPremium ?? false) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.verified,
                            color: Colors.amberAccent, size: 20),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? user?.phone ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: (user?.isPremium ?? false)
                          ? Colors.amber.withOpacity(0.25)
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (user?.isPremium ?? false)
                          ? 'PREMIUM MEMBER'
                          : 'FREE MEMBER',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStat('Tests', testsAttempted.toString()),
                      _buildStat('Avg %', avgPct.toStringAsFixed(0)),
                      _buildStat('Score', totalScore.toString()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Premium card if not premium
            if (!(user?.isPremium ?? false))
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium,
                      color: AppTheme.accentColor),
                  title: const Text('Upgrade to Premium'),
                  subtitle: const Text('Unlock all features'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PremiumScreen()),
                      );
                    },
                    child: const Text('Upgrade'),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Menu Items
            _buildMenuTile(
              context,
              Icons.history,
              'Test History',
              null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TestHistoryScreen()),
                );
              },
            ),
            _buildMenuTile(
              context,
              Icons.bookmark,
              'Bookmarks',
              null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                );
              },
            ),
            _buildMenuTile(
              context,
              Icons.newspaper,
              'Current Affairs',
              null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CurrentAffairsScreen()),
                );
              },
            ),
            _buildMenuTile(
              context,
              Icons.dark_mode,
              'Dark Mode',
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.toggleTheme();
                    },
                  );
                },
              ),
              trailingInsteadOfArrow: true,
            ),
            _buildMenuTile(
              context,
              Icons.share,
              'Share App',
              null,
              onTap: () {},
            ),
            _buildMenuTile(
              context,
              Icons.star,
              'Rate Us',
              null,
              onTap: () {},
            ),
            _buildMenuTile(
              context,
              Icons.help,
              'Help & Support',
              null,
              onTap: () {},
            ),
            _buildMenuTile(
              context,
              Icons.description,
              'Privacy Policy',
              null,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            // Logout
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: AppTheme.errorColor),
                label: const Text(
                  'Logout',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.errorColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    IconData icon,
    String title,
    Widget? trailing, {
    bool trailingInsteadOfArrow = false,
    VoidCallback? onTap,
  }) {
    if (!trailingInsteadOfArrow && onTap != null) {
      return _buildMenuTileWithOnTap(context, icon, title, onTap);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(title),
        trailing: trailingInsteadOfArrow
            ? trailing
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap ?? (trailingInsteadOfArrow ? null : () {}),
      ),
    );
  }

  Widget _buildMenuTileWithOnTap(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
