// =============================================================================
// ExamVault - Profile Screen
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/firestore_service.dart';
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
                    child: auth.user?.photoUrl != null
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: auth.user!.photoUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.person, size: 50, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    auth.user?.name ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.user?.email ?? auth.user?.phoneNumber ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStat('Tests', auth.user?.totalTestsAttempted.toString() ?? '0'),
                      _buildStat('XP', auth.user?.totalXp.toString() ?? '0'),
                      _buildStat('Level', auth.user?.level.toString() ?? '1'),
                      _buildStat('Streak', '${auth.user?.streak ?? 0}🔥'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Premium card if not premium
            if (!auth.isPremium)
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium, color: AppTheme.accentColor),
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
                  MaterialPageRoute(builder: (_) => const CurrentAffairsScreen()),
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
              onTap: () {
                // Share app
              },
            ),
            _buildMenuTile(
              context,
              Icons.star,
              'Rate Us',
              null,
              onTap: () {
                // Rate app
              },
            ),
            _buildMenuTile(
              context,
              Icons.help,
              'Help & Support',
              null,
              onTap: () {
                // Help
              },
            ),
            _buildMenuTile(
              context,
              Icons.description,
              'Privacy Policy',
              null,
              onTap: () {
                // Privacy policy
              },
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
