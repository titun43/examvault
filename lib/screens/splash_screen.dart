// =============================================================================
// ExamVault - Splash Screen
// =============================================================================
// IMPORTANT: This screen waits for Firebase Auth to FINISH restoring any
// persisted session before deciding where to navigate. Previously it used a
// fixed 3-second delay, but Firebase Auth restores sessions asynchronously —
// on a cold start (or slow device) the restore can take longer than 3s, so a
// logged-in user would be wrongly sent to the login screen and forced to
// log in again every time they reopened the app.
//
// VISUALS: Book logo (Icons.menu_book) zooms in over ~1s, then an animated
// "opening book" plays on a loop below the tagline (replaces the old round
// CircularProgressIndicator). The book cover swings open to reveal the pages,
// then closes and re-opens — a branded loading state while auth resolves.
// =============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
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
              // Book logo with a ~1s zoom-in animation.
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
              const SizedBox(height: 40),
              // Animated opening book — replaces the old round
              // CircularProgressIndicator. The cover swings open to reveal
              // the pages, then closes and re-opens in a gentle loop, giving
              // continuous branded loading feedback while Firebase Auth
              // restores any persisted session in the background.
              const _OpeningBook(),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _OpeningBook — an animated book that opens and closes on a loop.
// =============================================================================
// Built with a custom AnimationController + 3D `rotateY` transform. The book
// is a Stack:
//   - Bottom: the open pages (two white panels with "text lines").
//   - Top:    the front cover (gradient panel) which rotates open around its
//             left edge (the spine).
// As `t` goes 0 → 0.5 the cover opens (rotateY 0 → -92°); 0.5 → 1.0 it closes
// back. A subtle scale "breathe" runs in parallel so the book feels alive.
// =============================================================================
class _OpeningBook extends StatefulWidget {
  const _OpeningBook();

  @override
  State<_OpeningBook> createState() => _OpeningBookState();
}

class _OpeningBookState extends State<_OpeningBook>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _coverAngle;
  late final Animation<double> _breathe;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // Cover rotation: 0 (closed) → -92° (open) at t=0.5, back to 0 at t=1.
    // Using a CurveTween so the open/close has a natural ease-in-out.
    _coverAngle = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Gentle breathe: scale 1.0 → 1.04 → 1.0 over each full cycle.
    _breathe = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.04)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double bookW = 88.0;
    const double bookH = 64.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Map the 0..1 controller value to a cover-open fraction:
        // 0 → 0.5: open (0 → 1); 0.5 → 1: close (1 → 0).
        final double t = _coverAngle.value;
        final double openFraction = t < 0.5 ? (t / 0.5) : (1.0 - (t - 0.5) / 0.5);
        // Max open angle ~92° so the cover swings just past flat (looks like a
        // real book lying open).
        final double angleDeg = -92.0 * openFraction;
        // Hide the pages while the cover is mostly closed (openFraction < 0.12)
        // so the closed book looks like a solid cover, not two panels.
        final double pagesOpacity =
            openFraction < 0.12 ? 0.0 : ((openFraction - 0.12) / 0.25).clamp(0.0, 1.0);

        return Transform.scale(
          scale: _breathe.value,
          child: SizedBox(
            width: bookW + 16,
            height: bookH + 16,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ---- Open pages (visible once the cover starts opening) ----
                Opacity(
                  opacity: pagesOpacity,
                  child: _buildPages(bookW, bookH),
                ),
                // ---- Front cover (rotates open around the left spine) ----
                Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012) // perspective
                    ..rotateY(_toRadians(angleDeg)),
                  child: _buildCover(bookW, bookH),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The front cover — a gradient panel with the ExamVault "E" mark.
  Widget _buildCover(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFE3F2FD)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
          bottomLeft: Radius.circular(6),
        ),
        border: Border.all(color: const Color(0xFF1565C0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'E',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1565C0),
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }

  /// The open pages — two white panels with faint "text lines", shown once
  /// the cover has swung open.
  Widget _buildPages(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _buildPageLines()),
          // Spine line down the middle
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 6),
            color: const Color(0xFFBBBBBB),
          ),
          Expanded(child: _buildPageLines()),
        ],
      ),
    );
  }

  Widget _buildPageLines() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _line(w * 0.90),
              _line(w * 0.70),
              _line(w * 0.80),
              _line(w * 0.60),
              _line(w * 0.85),
            ],
          ),
        );
      },
    );
  }

  Widget _line(double width) {
    return Container(
      width: width,
      height: 2.5,
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withOpacity(0.25),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  double _toRadians(double deg) => deg * (math.pi / 180.0);
}
