// =============================================================================
// ExamVault - Profile Screen
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../config/app_config.dart';
import '../../models/user_model.dart';
import '../../utils/streak_helper.dart';
import '../../widgets/weekly_streak_indicator.dart';
import '../auth/login_screen.dart';
import '../home/main_navigation.dart';
import '../premium/premium_screen.dart';
import '../search/search_screen.dart';
import '../current_affairs/current_affairs_screen.dart';
import '../support/help_support_screen.dart';
import 'settings_screen.dart';
import 'test_history_screen.dart';
import 'bookmarks_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // ==================== Action handlers ====================
  // These were previously empty `// Share app` stubs, which is why tapping
  // Share App / Rate Us / Help & Support / Privacy Policy did nothing.

  Future<void> _shareApp(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final storeUrl = 'https://play.google.com/store/apps/details?id=${info.packageName}';
      await Share.share(
        'Check out ExamVault - India\'s #1 MCQ Mock Test app for Railway, SSC, UPSC, Banking & more!\n\n'
        'Download now: $storeUrl',
        subject: 'ExamVault - Mock Test App',
      );
    } catch (e) {
      _showToast(context, 'Unable to share app right now');
    }
  }

  Future<void> _rateApp(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final storeUrl = 'https://play.google.com/store/apps/details?id=${info.packageName}';
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showToast(context, 'Opening Play Store...');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showToast(context, 'Unable to open Play Store right now');
    }
  }

  Future<void> _openHelpSupport(BuildContext context) async {
    // Open the in-app support chat screen instead of an external mailto: link.
    // Users can start a new conversation or continue an existing one; replies
    // from the admin panel appear in real-time. See help_support_screen.dart.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    try {
      final uri = Uri.parse(AppConfig.privacyPolicyUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showToast(context, 'Unable to open Privacy Policy');
      }
    } catch (e) {
      _showToast(context, 'Unable to open Privacy Policy');
    }
  }

  void _showToast(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          // Global search — available on every bottom-nav tab, not just Home.
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
          ),
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
            // GUEST MODE — show a prominent sign-in card instead of the user
            // profile header. Guests can browse the app and take free tests,
            // but they need an account to save progress, buy premium, or sync
            // across devices. The card lists what they get by signing in.
            if (auth.isGuest) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Guest Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You\'re browsing as a guest. Sign in to unlock premium tests, save your progress, and sync across devices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.login),
                        label: const Text(
                          'Sign In / Sign Up',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
            // Profile Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: auth.user?.photoUrl != null &&
                                auth.user!.photoUrl!.isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: auth.user!.photoUrl!,
                                  fit: BoxFit.cover,
                                  // Explicit size required so the image fills
                                  // the 100x100 circle (radius 50). Without
                                  // width/height, BoxFit.cover has no box to
                                  // fill and the photo renders distorted or
                                  // partial after save.
                                  width: 100,
                                  height: 100,
                                  placeholder: (_, __) => const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: AppTheme.primaryColor),
                                  errorWidget: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: AppTheme.primaryColor),
                                ),
                              )
                            : const Icon(Icons.person, size: 50, color: AppTheme.primaryColor),
                      ),
                      // Premium badge — a crown icon + "PREMIUM" label shown
                      // on the avatar's bottom-right. Visible only for active
                      // premium users. Survives re-login because premium status
                      // is persisted in Firestore (isPremium + subscriptionExpiry).
                      if (auth.isPremium)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.workspace_premium,
                                    size: 12, color: Colors.white),
                                SizedBox(width: 3),
                                Text(
                                  'PREMIUM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      auth.user?.name ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (auth.isPremium) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified,
                        color: Color(0xFFFFD700), size: 18),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                auth.user?.email ?? auth.user?.phoneNumber ?? '',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                ),
              ),
              // Premium status line — shows "Premium member" + expiry date
              if (auth.isPremium &&
                  auth.user?.subscriptionExpiry != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Premium until ${_formatExpiry(auth.user!.subscriptionExpiry!)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat('Tests', auth.user?.totalTestsAttempted.toString() ?? '0'),
                  _buildStat('XP', auth.user?.totalXp.toString() ?? '0'),
                  _buildStat('Level', auth.user?.level.toString() ?? '1'),
                  // Streak is computed client-side from `streak` + `lastActiveAt`
                  // so a broken streak shows 0 immediately instead of waiting
                  // for the next test submission to reset it server-side.
                  _buildStat(
                    'Streak',
                    '${computeEffectiveStreak(auth.user?.streak ?? 0, auth.user?.lastActiveAt)}🔥',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Weekly streak indicator — 7 dots (Mon→Sun) showing which days
              // the user was active this week. Renders on the dark header so
              // we pass light colors for the inactive state.
              _buildHeaderWeeklyStreak(auth.user?.lastActiveAt),
            ],
          ),
        ),
            ], // end else (logged-in profile header)
            const SizedBox(height: 16),
            // Personal Info card — shows DOB, qualification, city, target exam
            // if the user has filled them in via EditProfileScreen.
            if (!auth.isGuest) ...[
            _buildPersonalInfoCard(context, auth.user),
            const SizedBox(height: 16),
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
              Icons.receipt_long,
              'My Purchases',
              null,
              onTap: () {
                Navigator.pushNamed(context, '/my-purchases');
              },
            ),
            ], // end if (!auth.isGuest) for user-specific menu items
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
              onTap: () => _shareApp(context),
            ),
            _buildMenuTile(
              context,
              Icons.star,
              'Rate Us',
              null,
              onTap: () => _rateApp(context),
            ),
            _buildMenuTile(
              context,
              Icons.help,
              'Help & Support',
              null,
              onTap: () => _openHelpSupport(context),
            ),
            _buildMenuTile(
              context,
              Icons.description,
              'Privacy Policy',
              null,
              onTap: () => _openPrivacyPolicy(context),
            ),
            const SizedBox(height: 16),
            // Logout (logged-in) / Sign In (guest)
            SizedBox(
              width: double.infinity,
              child: auth.isGuest
                ? OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.login, color: AppTheme.primaryColor),
                    label: const Text(
                      'Sign In / Sign Up',
                      style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryColor),
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () async {
                      await auth.logout();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const MainNavigation()),
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

  /// Formats the premium subscription expiry date for display under the
  /// user's name in the profile header (e.g. "Premium until 15 Aug 2026").
  String _formatExpiry(DateTime expiry) {
    return DateFormat('d MMM yyyy').format(expiry);
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

  /// Weekly streak indicator rendered inside the dark profile header. Uses
  /// translucent white tones so it stays legible over the gradient.
  Widget _buildHeaderWeeklyStreak(DateTime? lastActiveAt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 12, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                'This Week',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          WeeklyStreakIndicator(
            lastActiveAt: lastActiveAt,
            activeColor: AppTheme.accentColor,
            inactiveColor: Colors.white30,
            labelColor: Colors.white60,
            dotSize: 26,
          ),
        ],
      ),
    );
  }

  /// Personal Info card — shows the user's extended profile fields (DOB,
  /// gender, qualification, city, target exam) if any have been set. Returns
  /// an empty widget if the user hasn't filled any of these yet, so new users
  /// don't see an empty card.
  Widget _buildPersonalInfoCard(BuildContext context, UserModel? user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = <Widget>[];

    void addRow(IconData icon, String label, String? value) {
      if (value == null || value.trim().isEmpty) return;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            Text(
              '$label: ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ));
    }

    // DOB
    final dob = user?.dateOfBirth;
    if (dob != null) {
      addRow(Icons.cake_outlined, 'DOB',
          '${dob.day}/${dob.month}/${dob.year}');
    }
    // Gender
    addRow(Icons.wc_outlined, 'Gender', user?.gender);
    // Qualification
    addRow(Icons.school_outlined, 'Qualification', user?.qualification);
    // City
    addRow(Icons.location_city_outlined, 'City', user?.city);
    // Target Exam
    addRow(Icons.flag_outlined, 'Target Exam', user?.targetExam);

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Personal Info',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ...rows,
          ],
        ),
      ),
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
