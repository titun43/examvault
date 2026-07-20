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
// VISUALS: The book logo (the white rounded panel with the menu_book icon that
// sits above the "ExamVault" wordmark) now performs a ONE-SHOT "opening book"
// intro animation — the cover swings open around its left spine (3D rotateY)
// to reveal two pages with faint text lines, then settles open. This replaces
// the old separate _OpeningBook widget that used to loop below the tagline.
// A subtle breathing scale keeps the open book feeling alive while Firebase
// Auth restores any persisted session in the background.
//
// GUEST MODE: If the user is not authenticated after Firebase Auth resolves
// (or the safety timeout fires), they are taken straight into MainNavigation
// as a GUEST — they can browse all content and take FREE tests without an
// account. Premium / paid content prompts them to sign in. Admins still route
// to the admin dashboard.
// =============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import '../models/action_button.dart';
import '../models/app_open_banner_model.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../utils/app_open_banner_frequency.dart';
import '../utils/in_app_navigator.dart' show runActionButton;
import '../theme/app_theme.dart';
import '../theme/app_fonts.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_open_banner_dialog.dart';
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
      // Safety timeout: treat as not-authenticated and go to guest mode.
      _doNavigate();
      return;
    }

    Future.delayed(const Duration(milliseconds: 200), _maybeNavigate);
  }

  void _doNavigate() {
    if (!mounted || _navigated) return;
    _navigated = true;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Resolve destination FIRST so we can show the app-open banner (if any)
    // before pushing the main screen.
    final Widget dest;
    if (authProvider.isAuthenticated) {
      dest = authProvider.isAdmin
          ? const AdminDashboard()
          : const MainNavigation();
    } else {
      dest = const MainNavigation();
    }

    // Try to show an app-open banner between splash and the destination.
    // Failures (network error, no banner, frequency cap hit, audience
    // mismatch) are silent — we always push the destination so the user is
    // never stuck on the splash.
    _maybeShowAppOpenBannerThenNavigate(dest);
  }

  Future<void> _maybeShowAppOpenBannerThenNavigate(Widget dest) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isGuest = !authProvider.isAuthenticated;
    final isPremium = authProvider.user?.isPremium ?? false;

    AppOpenBannerModel? banner;
    try {
      banner = await FirestoreService.fetchActiveAppOpenBanner(
        isGuest: isGuest,
        isPremium: isPremium,
      );
    } catch (_) {
      banner = null;
    }

    // Frequency cap check (urgent banners bypass this).
    bool shouldShow = false;
    if (banner != null) {
      try {
        shouldShow =
            await AppOpenBannerFrequencyController.shouldShow(banner);
      } catch (_) {
        shouldShow = false;
      }
    }

    // Show the dialog (if applicable) and capture the tapped action — but do
    // NOT run it here. Running it before pushReplacement would cause the
    // splash's pushReplacement to replace the in-app screen the action just
    // pushed. Instead we hand the action to _BannerActionRunner below, which
    // runs it AFTER the destination is mounted.
    ActionButton? tappedAction;
    if (banner != null && shouldShow && mounted) {
      // Mark as shown BEFORE the dialog appears so a quick double-trigger
      // doesn't show it twice.
      await AppOpenBannerFrequencyController.markShown(banner);
      if (!mounted) return;
      tappedAction = await AppOpenBannerDialog.show(context, banner);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _BannerActionRunner(child: dest, action: tappedAction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppTheme.brandGradient,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Book logo with a one-shot "opening book" intro animation.
              // The cover swings open around its left spine to reveal two
              // pages, then settles. Replaces both the old static ZoomIn logo
              // AND the old separate _OpeningBook loop widget.
              const _BookLogo(),
              const SizedBox(height: 30),
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 600),
                child: Text(
                  'ExamVault',
                  style: AppFonts.style(
                    size: 36,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                delay: const Duration(milliseconds: 900),
                child: Builder(
                  builder: (context) => L10nText(
                    'splash_tagline',
                    style: AppFonts.style(
                      size: 16,
                      weight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _BookLogo — the ExamVault book logo that opens like a real book.
// =============================================================================
// A 120×120 panel. The "cover" is a white rounded panel carrying the
// menu_book icon; it rotates open around its LEFT edge (the spine) using a 3D
// rotateY transform with perspective. Underneath the cover sit two "pages"
// (white panels with faint text lines) that become visible as the cover
// swings away.
//
// Animation timeline (one-shot intro, ~1.6s total):
//   t=0.0–0.15 : hold closed (let the panel zoom/scale in via parent).
//   t=0.15–0.75: cover swings open (rotateY 0 → -118°) with easeOutCubic.
//   t=0.75–1.0 : settle — cover nudges slightly back to -110° for a natural
//                "lie flat" look.
//   t>1.0      : a gentle breathing scale (1.0 ↔ 1.03) loops forever so the
//                open book feels alive while auth resolves.
//
// Built with a single AnimationController + TweenSequence so the whole intro
// is one smooth, uninterrupted motion.
// =============================================================================
class _BookLogo extends StatefulWidget {
  const _BookLogo();

  @override
  State<_BookLogo> createState() => _BookLogoState();
}

class _BookLogoState extends State<_BookLogo>
    with TickerProviderStateMixin {
  // Two controllers so the cover opens ONCE and only the gentle breathing
  // loops forever. A single repeating controller would re-close the cover
  // on each cycle, which is not what we want.
  late final AnimationController _introController;
  late final AnimationController _breatheController;
  late final Animation<double> _coverAngle; // degrees, 0 = closed
  late final Animation<double> _pagesOpacity;
  late final Animation<double> _breathe;

  @override
  void initState() {
    super.initState();
    // Intro controller — one-shot, ~1.6s. Drives the cover swing + page fade.
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    // Breathing controller — slow loop that starts AFTER the intro so the
    // open book keeps feeling alive while Firebase Auth resolves.
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _breatheController.repeat(reverse: true);
      }
    });
    _introController.forward();

    // Cover angle (degrees). 0 = closed, negative = opening to the left.
    // Sequence: hold closed briefly → swing open → settle.
    _coverAngle = TweenSequence<double>([
      TweenSequenceItem(
        // Hold closed for a beat so the zoom-in registers.
        tween: ConstantTween<double>(0.0),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -118.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60,
      ),
      TweenSequenceItem(
        // Settle back a touch so the cover looks like it's lying flat.
        tween: Tween<double>(begin: -118.0, end: -110.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_introController);

    // Pages fade in as the cover opens (from ~25% open onward).
    _pagesOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 25,
      ),
    ]).animate(_introController);

    // Breathing scale: 1.0 ↔ 1.03, ease-in-out, loops via the breathe
    // controller (which only starts after the intro finishes).
    _breathe = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _breatheController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double panelW = 120.0;
    const double panelH = 120.0;

    return AnimatedBuilder(
      animation: Listenable.merge([_introController, _breatheController]),
      builder: (context, _) {
        return Transform.scale(
          scale: _breathe.value,
          child: SizedBox(
            width: panelW,
            height: panelH,
            child: Stack(
              children: [
                // ---- Pages (visible once the cover starts opening) ----
                // Slightly smaller than the cover so they read as inner pages.
                Positioned.fill(
                  child: Opacity(
                    opacity: _pagesOpacity.value,
                    child: _buildPages(panelW - 16, panelH - 16),
                  ),
                ),
                // ---- Cover (rotates open around the left spine) ----
                Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0018) // perspective
                    ..rotateY(_toRadians(_coverAngle.value)),
                  child: _buildCover(panelW, panelH),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The front cover — white rounded panel with the ExamVault book icon.
  Widget _buildCover(double w, double h) {
    return Container(
      width: w,
      height: h,
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
        color: AppTheme.primaryColor,
      ),
    );
  }

  /// The open pages — two white panels with faint "text lines", shown once
  /// the cover has swung open.
  Widget _buildPages(double w, double h) {
    return Center(
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(child: _buildPageLines()),
            // Spine line down the middle
            Container(
              width: 1.5,
              margin: const EdgeInsets.symmetric(vertical: 14),
              color: const Color(0xFFBBBBBB),
            ),
            Expanded(child: _buildPageLines()),
          ],
        ),
      ),
    );
  }

  Widget _buildPageLines() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _line(w * 0.85),
              _line(w * 0.65),
              _line(w * 0.78),
              _line(w * 0.55),
              _line(w * 0.72),
            ],
          ),
        );
      },
    );
  }

  Widget _line(double width) {
    return Container(
      width: width,
      height: 3,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.22),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  double _toRadians(double deg) => deg * (math.pi / 180.0);
}

// =============================================================================
// _BannerActionRunner — runs a banner CTA action AFTER the splash
// destination (home / admin dashboard) is mounted.
//
// WHY: The app-open banner dialog returns the tapped ActionButton to the
// splash screen. If the splash ran the action directly (before
// pushReplacement), the subsequent pushReplacement would REPLACE the
// in-app screen the action just pushed — so the user would end up on Home
// instead of the CTA destination. By wrapping the destination in this
// widget, the action is scheduled via addPostFrameCallback once the
// destination is in the tree, so it pushes ON TOP of Home.
//
// For external-URL actions this is a harmless no-op difference (the URL
// opens in the browser either way). For in-app actions it is the fix that
// makes navigation actually reach the configured screen.
// =============================================================================
class _BannerActionRunner extends StatefulWidget {
  final Widget child;
  final ActionButton? action;

  const _BannerActionRunner({required this.child, this.action});

  @override
  State<_BannerActionRunner> createState() => _BannerActionRunnerState();
}

class _BannerActionRunnerState extends State<_BannerActionRunner> {
  bool _ran = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeRun();
  }

  void _maybeRun() {
    if (_ran || widget.action == null) return;
    _ran = true;
    final action = widget.action!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      runActionButton(context, action);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
