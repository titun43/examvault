// =============================================================================
// ExamVault - Main Navigation (Bottom Nav with Home, Tests, Leaderboard, Profile)
// =============================================================================
// BUGFIX (offline indicator): Added ConnectivityBanner at the top of every
// screen so the user always knows when they're offline. Previously the app
// had no offline indicator at all — the connectivity_plus package was in
// pubspec.yaml but NEVER used. When offline, every StreamBuilder just showed
// an infinite spinner with no explanation, which the user reported as
// "app offline kaj kore na".
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examvault/screens/home/home_screen.dart';
import 'package:examvault/screens/tests/test_series_screen.dart';
import 'package:examvault/screens/leaderboard/leaderboard_screen.dart';
import 'package:examvault/screens/profile/profile_screen.dart';
import 'package:examvault/widgets/connectivity_banner.dart';
import 'package:examvault/theme/app_theme.dart';

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
          title: const Text('Exit App?'),
          content: const Text('Do you really want to exit ExamVault?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // PopScope intercepts the Android system back button.
    // canPop:false prevents immediate pop; onPopInvoked fires so we can show
    // the exit confirmation dialog instead of instantly quitting.
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
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
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
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
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.quiz_outlined),
                activeIcon: Icon(Icons.quiz),
                label: 'Tests',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard_outlined),
                activeIcon: Icon(Icons.leaderboard),
                label: 'Ranks',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
