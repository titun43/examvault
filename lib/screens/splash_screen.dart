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
import '../services/category_preference_service.dart';
import 'onboarding/category_selection_screen.dart';

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

    // Admins no longer have an in-app dashboard — they use the separate
    // web admin panel at github.com/titun43/examvault-admin. Anyone signed
    // in (admin or not) lands on MainNavigation.
    const Widget dest = MainNavigation();

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

    // First-run category picker: shown once per device (flag lives in
    // SharedPreferences), before MainNavigation. Applies to guests and
    // regular users alike.
    Widget resolvedDest = dest;
    if (dest is MainNavigation) {
      final onboarded = await CategoryPreferenceService.hasCompletedOnboarding();
      if (!onboarded) {
        resolvedDest = const CategorySelectionScreen();
      }
    }
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _BannerActionRunner(child: resolvedDest, action: tappedAction),
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
// _BookLogo — REAL book opening animation.
// =============================================================================
// A book viewed from the front that opens like a real book:
//
//   ┌─────────────┐         ┌─────────┐│┌─────────┐
//   │  ╔═══════╗  │         │ inside  │││  page 1  │
//   │  ║ 📖    ║  │  ──►    │ cover   │││  text    │
//   │  ║       ║  │         │         │││  lines   │
//   │  ╚═══════╝  │         └─────────┘│└─────────┘
//   └─────────────┘              spine
//     CLOSED                      OPEN
//
// Structure (back to front in the Stack):
//   1. Spine — thin dark-emerald strip on the left (always visible)
//   2. Pages — white two-page spread (title page + content page), fades in
//   3. Shadow — gradient cast by the cover onto the pages (peaks at 90°)
//   4. Front cover — emerald gradient + gold border + icon + title,
//      rotates open around the left spine via 3D rotateY
//
// Animation timeline (one-shot intro, ~1.8s total):
//   t=0.00–0.15 : entrance scale (0.85 → 1.0) with easeOutBack
//   t=0.15–0.25 : hold closed (let the cover design register)
//   t=0.25–0.80 : cover swings open (rotateY 0 → -165°) with easeOutCubic
//   t=0.80–1.00 : settle with slight elastic bounce to -170°
//   t>1.00      : gentle breathing scale (1.0 ↔ 1.02) loops forever
//
// Realistic touches:
//   - Cover has a designed look: emerald gradient, gold inner border,
//     menu_book icon in a circle, "ExamVault" wordmark
//   - Pages show a title page (left) with icon + decorative line + text
//     lines, and a content page (right) with varied text lines
//   - Shadow gradient simulates the cover casting a shadow on pages as it
//     passes overhead (peaks at 90°, fades as cover lies flat)
//   - Spine is always visible as the book's left edge
// =============================================================================
class _BookLogo extends StatefulWidget {
  const _BookLogo();

  @override
  State<_BookLogo> createState() => _BookLogoState();
}

class _BookLogoState extends State<_BookLogo>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _breatheController;

  late final Animation<double> _coverAngle;
  late final Animation<double> _pagesOpacity;
  late final Animation<double> _shadowOpacity;
  late final Animation<double> _entranceScale;
  late final Animation<double> _breathe;

  // Book dimensions — wider than tall, like a real book.
  static const double _bookW = 130.0;
  static const double _bookH = 100.0;
  static const double _spineW = 5.0;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _breatheController.repeat(reverse: true);
      }
    });
    _introController.forward();

    // Entrance scale: 0.85 → 1.0 in first 15%, then hold.
    _entranceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 85,
      ),
    ]).animate(_introController);

    // Cover angle: hold (15%) → swing open (65%) → settle bounce (20%)
    _coverAngle = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -165.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -165.0, end: -170.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_introController);

    // Pages fade in from 25% onward (as cover passes ~90°)
    _pagesOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 30,
      ),
    ]).animate(_introController);

    // Shadow on pages: peaks at ~50% (cover at 90° overhead), fades as
    // cover lies flat. Simulates the cover casting a shadow on the pages.
    _shadowOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.4)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
    ]).animate(_introController);

    _breathe = Tween<double>(begin: 1.0, end: 1.02).animate(
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
    return AnimatedBuilder(
      animation: Listenable.merge([_introController, _breatheController]),
      builder: (context, _) {
        return Transform.scale(
          scale: _breathe.value * _entranceScale.value,
          child: SizedBox(
            width: _bookW + _spineW,
            height: _bookH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ---- Spine (left edge, always visible) ----
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: _spineW,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDarkColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        bottomLeft: Radius.circular(3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(-1, 0),
                        ),
                      ],
                    ),
                  ),
                ),
                // ---- Pages (revealed as cover opens) ----
                Positioned(
                  left: _spineW,
                  top: 0,
                  child: Opacity(
                    opacity: _pagesOpacity.value,
                    child: _buildPages(),
                  ),
                ),
                // ---- Shadow cast by cover onto pages ----
                Positioned(
                  left: _spineW,
                  top: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: _shadowOpacity.value,
                      child: Container(
                        width: _bookW,
                        height: _bookH,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withOpacity(0.35),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.6],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
                // ---- Front cover (rotates open around left spine) ----
                Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002) // perspective
                    ..rotateY(_toRadians(_coverAngle.value)),
                  child: Container(
                    margin: const EdgeInsets.only(left: _spineW),
                    child: _buildCover(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The front cover — emerald gradient with gold border, icon, and title.
  Widget _buildCover() {
    return Container(
      width: _bookW,
      height: _bookH,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppTheme.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppTheme.accentColor.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppTheme.accentColor.withOpacity(0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Book icon in a translucent circle
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                ),
                child: const Icon(
                  Icons.menu_book,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ExamVault',
                style: AppFonts.style(
                  size: 9,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              // Decorative gold line
              Container(
                width: 24,
                height: 1.5,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The open pages — two-page spread with a center spine line.
  Widget _buildPages() {
    return Container(
      width: _bookW,
      height: _bookH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left page — title page (icon + decorative line + text)
          Expanded(child: _buildTitlePage()),
          // Center spine shadow
          Container(
            width: 1,
            decoration: BoxDecoration(
              color: const Color(0xFFD6D3D1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 2,
                  offset: const Offset(1, 0),
                ),
              ],
            ),
          ),
          // Right page — content with text lines
          Expanded(child: _buildContentPage()),
        ],
      ),
    );
  }

  /// Left page — a title page with a small icon and decorative elements.
  Widget _buildTitlePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school,
            size: 16,
            color: AppTheme.primaryColor.withOpacity(0.4),
          ),
          const SizedBox(height: 3),
          Container(
            width: 20,
            height: 1.5,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 4),
          ...List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _line(18 + i * 4, opacity: 0.12),
            );
          }),
        ],
      ),
    );
  }

  /// Right page — content page with varied text lines.
  Widget _buildContentPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _line(32, opacity: 0.28),
          const SizedBox(height: 2),
          _line(22, opacity: 0.18),
          _line(28, opacity: 0.18),
          _line(20, opacity: 0.18),
          const SizedBox(height: 3),
          _line(30, opacity: 0.22),
          const SizedBox(height: 2),
          _line(18, opacity: 0.14),
          _line(24, opacity: 0.14),
        ],
      ),
    );
  }

  Widget _line(double width, {double opacity = 0.22}) {
    return Container(
      width: width,
      height: 2,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(opacity),
        borderRadius: BorderRadius.circular(1),
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
