// =============================================================================
// ExamVault - Main Navigation (Bottom Nav with Home, Tests, Leaderboard, Profile)
// =============================================================================
// BUGFIX (offline indicator): Added ConnectivityBanner at the top of every
// screen so the user always knows when they're offline. Previously the app
// had no offline indicator at all — the connectivity_plus package was in
// pubspec.yaml but NEVER used. When offline, every StreamBuilder just showed
// an infinite spinner with no explanation, which the user reported as
// "app offline kaj kore na".
//
// v2 MODERNIZATION (Phase 3.2 — visual layer only):
//   - Bottom-nav labels now flow through tr() (nav_home / nav_exams / nav_ranks
//     / nav_profile) so the labels respect the user's language preference
//     (English / অসমীয়া / Both). Wrapped the bottomNavigationBar in a
//     Consumer<LanguageProvider> so labels rebuild immediately when the user
//     changes language in Settings.
//   - Bottom-nav shadow swapped from inline Colors.black.withOpacity(0.05) to
//     the AppTheme.softShadow1 design token (preserving the upward direction
//     so the shadow reads correctly above the nav bar).
//   - Exit confirmation dialog modernized: AppTheme.radiusLg corners, AppFonts
//     on every text (so Assamese renders), bilingual labels via L10nText
//     (exit_title / exit_confirm / cancel / exit_button), error-color FilledButton.
//   - flutter_animate entrance (fadeIn + slideY) for the bottom nav so it
//     slides up into place on first paint.
//   - PopScope.onPopInvoked upgraded to onPopInvokedWithResult (newer Flutter
//     API) to silence the deprecation warning.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:examvault/screens/home/home_screen.dart';
import 'package:examvault/screens/tests/test_series_screen.dart';
import 'package:examvault/screens/leaderboard/leaderboard_screen.dart';
import 'package:examvault/screens/profile/profile_screen.dart';
import 'package:examvault/widgets/connectivity_banner.dart';
import 'package:examvault/theme/app_theme.dart';
import 'package:examvault/theme/app_fonts.dart';
import 'package:examvault/l10n/app_localizations.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const TestSeriesScreen(),
    const LeaderboardScreen(),
    const ProfileScreen(),
  ];

  // Show the "Exit App?" confirmation dialog.
  // If the user is not on the Home tab, first switch them back to Home so the
  // back button behaves like a normal bottom-nav app (back-to-home, then exit).
  Future<void> _showExitDialog() async {
    if (!mounted) return;
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          title: L10nText(
            'exit_title',
            style: AppFonts.style(
              size: 18,
              weight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: L10nText(
            'exit_confirm',
            style: AppFonts.style(
              size: 14,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: L10nText(
                'cancel',
                style: AppFonts.style(
                  size: 14,
                  weight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
              child: L10nText(
                'exit_button',
                style: AppFonts.style(
                  size: 14,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // PopScope intercepts the Android system back button.
    // canPop:false prevents immediate pop; onPopInvokedWithResult fires so we
    // can show the exit confirmation dialog instead of instantly quitting.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showExitDialog();
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            // BUGFIX: Global offline indicator. Shows a slim orange banner at
            // the top of every tab when the device has no internet. Uses
            // connectivity_plus (was installed but unused before this fix).
            const ConnectivityBanner(),
            // The actual screen content fills the remaining space.
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
        // Wrap the bottom nav in a Consumer<LanguageProvider> so the labels
        // rebuild immediately when the user changes language in Settings
        // (without rebuilding the IndexedStack body).
        bottomNavigationBar: Consumer<LanguageProvider>(
          builder: (context, langProvider, _) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurfaceColor : Colors.white,
                boxShadow: [
                  BoxShadow(
                    // softShadow1 token — color + blurRadius. Offset flipped to
                    // (-2) so the shadow projects upward (above the nav bar),
                    // which is the correct direction for a bottom nav.
                    color: AppTheme.softShadow1.first.color,
                    blurRadius: AppTheme.softShadow1.first.blurRadius,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.home_outlined),
                    activeIcon: const Icon(Icons.home),
                    label: tr(context, 'nav_home'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.quiz_outlined),
                    activeIcon: const Icon(Icons.quiz),
                    label: tr(context, 'nav_exams'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.leaderboard_outlined),
                    activeIcon: const Icon(Icons.leaderboard),
                    label: tr(context, 'nav_ranks'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.person_outline),
                    activeIcon: const Icon(Icons.person),
                    label: tr(context, 'nav_profile'),
                  ),
                ],
              ),
            );
          },
        ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.15),
      ),
    );
  }
}
