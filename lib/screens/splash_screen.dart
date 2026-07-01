// =============================================================================
// ExamVault - Splash Screen
// =============================================================================
// IMPORTANT: This screen waits for Firebase Auth to FINISH restoring any
// persisted session before deciding where to navigate. Previously it used a
// fixed 3-second delay, but Firebase Auth restores sessions asynchronously —
// on a cold start (or slow device) the restore can take longer than 3s, so a
// logged-in user would be wrongly sent to the login screen and forced to
// log in again every time they reopened the app.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'home/main_navigation.dart';
import '../admin/admin_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _minSplashTime = Duration(seconds: 2);
  static const Duration _maxWaitTime = Duration(seconds: 10);

  bool _navigated = false;
  DateTime _startTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // Kick off the navigation check. It will listen to the auth provider and
    // navigate as soon as auth is ready (or the safety timeout fires).
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeNavigate());
  }

  void _maybeNavigate() {
    if (!mounted || _navigated) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final authReady = authProvider.authInitialized && !authProvider.isLoading;

    if (authReady) {
      // Auth state is determined. Enforce a minimum splash display time for
      // branding, then navigate.
      final elapsed = DateTime.now().difference(_startTime);
      final remaining = _minSplashTime - elapsed;
      if (remaining.isNegative) {
        _doNavigate();
      } else {
        Future.delayed(remaining, _doNavigate);
      }
      return;
    }

    // Auth not ready yet — check again shortly, but bail out after the safety
    // timeout so the user is never stuck on the splash forever.
    final elapsed = DateTime.now().difference(_startTime);
    if (elapsed > _maxWaitTime) {
      // Safety timeout: treat as not-authenticated and go to login.
      _doNavigate();
      return;
    }

    Future.delayed(const Duration(milliseconds: 200), _maybeNavigate);
  }

  void _doNavigate() {
    if (!mounted || _navigated) return;
    _navigated = true;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuthenticated) {
      // Route admins to the admin dashboard, students to the main app
      final dest = authProvider.isAdmin
          ? const AdminDashboard()
          : const MainNavigation();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => dest),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color(0xFF003C8F)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Book logo with a ~1s zoom-in animation (replaces the old
              // graduation-cap icon + circular progress spinner).
              ZoomIn(
                duration: const Duration(milliseconds: 1000),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.menu_book,
                    size: 60,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 300),
                child: const Text(
                  'ExamVault',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 600),
                child: Text(
                  'MCQ Mock Test Platform',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              // Loading spinner removed per user request — the 1s book-logo
              // animation is the only motion on the splash now.
            ],
          ),
        ),
      ),
    );
  }
}
