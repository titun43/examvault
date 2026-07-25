// =============================================================================
// ExamVault - Home Screen
// Shows: Banner carousel + Welcome + Quick actions + Announcements ticker +
// Categories + Popular subjects + Upcoming exams preview + Current affairs +
// Premium banner
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/category_model.dart';
import '../../models/subject_model.dart';
import '../../models/current_affair_model.dart';
import '../../models/announcement_model.dart';
import '../../models/upcoming_exam_model.dart';
import '../../models/banner_model.dart';
import '../../services/firestore_service.dart';
import '../../services/access_service.dart';
import '../../models/action_button.dart';
import '../../utils/in_app_navigator.dart';
import '../../utils/localized_content.dart';
import '../../services/razorpay_service.dart';
import '../../widgets/payment_progress_dialog.dart';
import '../../widgets/payment_success_dialog.dart';
import 'category_detail_screen.dart';
import '../auth/login_screen.dart';
import '../current_affairs/current_affairs_screen.dart';
import '../current_affairs/current_affair_detail_screen.dart';
import '../announcements/announcements_screen.dart';
import '../upcoming_exams/upcoming_exams_screen.dart';
import '../upcoming_exams/upcoming_exam_detail_screen.dart';
import '../premium/premium_screen.dart';
import '../tests/daily_quiz_screen.dart';
import '../tests/free_tests_screen.dart';
import '../tests/test_series_screen.dart';
import '../tests/test_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/bookmarks_screen.dart';
import '../search/search_screen.dart';
import 'all_subjects_screen.dart';
import 'all_categories_screen.dart';
import '../../services/category_preference_service.dart';
import '../onboarding/category_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Cached category list for resolving authoritative category IDs in subject cards.
  List<CategoryModel> _categories = [];
  /// Category IDs the user picked in onboarding/Profile > My Categories.
  /// Empty means "no filter — show everything" (same as before this feature).
  List<String> _selectedCategoryIds = [];
  /// True once the first batch of categories has arrived from Firestore.
  /// Used to decide whether to show shimmer or the real grid.
  bool _categoriesLoaded = false;
  // Single subscription — _buildCategoriesSection reads _categories directly
  // from local state instead of using a StreamBuilder, so there is only ONE
  // Firestore listener for categories. Having BOTH a StreamSubscription AND a
  // StreamBuilder was causing every Firestore event to rebuild the widget
  // twice: once for the subscription setState and once for the StreamBuilder.
  StreamSubscription<List<CategoryModel>>? _categoriesSub;

  // Banner carousel auto-scroll
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _currentBannerPage = 0;
  int _bannerCount = 0; // tracked so the auto-rotate can wrap with modulo
  // Signature of the last category payload we rendered. Used to skip no-op
  // rebuilds (see initState). Fixes the "screen flashing when scrolling" bug
  // caused by the admin count-sync write-back firing the stream repeatedly
  // with identical data.
  String _lastCategoriesSig = '';

  // Cached Firestore streams. Creating a stream inline inside build() is a
  // classic Flutter anti-pattern: every parent rebuild (the banner auto-scroll
  // setState fires every 4s, the category subscription setState, theme toggle,
  // premium state changes, etc.) hands each StreamBuilder a BRAND-NEW stream
  // object, so Flutter cancels the old subscription and re-subscribes —
  // resetting the connection state to "waiting" and flashing the shimmer
  // placeholder. This is why the sections below "Popular Subjects" kept
  // "reloading" every few seconds. Caching the stream instances once in
  // initState means StreamBuilder sees the same stream object across rebuilds
  // and never re-subscribes, so those sections stay stable.
  late final Stream<List<BannerModel>> _bannersStream;
  late final Stream<List<AnnouncementModel>> _announcementsStream;
  late final Stream<List<SubjectModel>> _subjectsStream;
  late final Stream<List<UpcomingExamModel>> _upcomingExamsStream;
  late final Stream<List<CurrentAffairModel>> _currentAffairsStream;

  // AuthProvider reference for listening to preferred-category changes
  // so Profile > My Categories propagates live to all Home sections.
  AuthProvider? _auth;

  @override
  void initState() {
    super.initState();
    _startBannerAutoScroll();
    // Cache the Firestore streams ONCE so the StreamBuilders below don't
    // re-subscribe (and flash shimmer) on every parent rebuild.
    _bannersStream = FirestoreService.getActiveBannersStream();
    _announcementsStream = FirestoreService.getAnnouncementsStream(limit: 5);
    _subjectsStream = FirestoreService.getSubjectsStream();
    _upcomingExamsStream = FirestoreService.getUpcomingExamsStream(limit: 3);
    _currentAffairsStream = FirestoreService.getCurrentAffairsStream(limit: 3);
    _loadSelectedCategoryIds();
    // Single subscription for categories. The grid reads _categories directly,
    // so there is no StreamBuilder double-listening.
    //
    // GUARD: only call setState when the category list actually changed.
    // The admin "Syncing counts" step (Task 2) writes subjectCount back to
    // category docs, which fires this stream repeatedly with the SAME data
    // (just a different subjectCount on a doc). Without this guard every
    // such write rebuilds the entire home screen — which, while the user is
    // scrolling, looks like a screen "flash". We compare a lightweight
    // signature (id+subjectCount+testCount+name) so count updates still
    // refresh the UI but identical payloads are skipped.
    _categoriesSub = FirestoreService.getCategoriesStream().listen((cats) {
      if (!mounted) return;
      // GUARD: only call setState when something the UI actually renders
      // changed. The signature must include EVERY field the category card
      // displays or reacts to — otherwise admin edits (premium toggle,
      // image upload, reorder, description edit) won't propagate to the
      // user app. Previously the signature only had id|name|subjectCount|icon
      // which meant toggling premium on/off in the admin had NO effect here
      // until the app restarted. Now it includes isPremium, premiumPrice,
      // premiumDurationMonths, image, color, order, and description.
      final newSig = cats
          .map((c) =>
              '${c.id}|${c.name}|${c.subjectCount}|${c.icon ?? ""}|${c.isPremium}|${c.premiumPrice}|${c.premiumDurationMonths}|${c.image ?? ""}|${c.color ?? ""}|${c.order}|${c.description ?? ""}')
          .join('§');
      if (newSig == _lastCategoriesSig && _categoriesLoaded) {
        // identical payload — skip rebuild to avoid scroll-position jump / flash
        return;
      }
      // Detect which categories had their premium status change so we can
      // clear the AccessService cache for JUST those (not all). Without this,
      // a stale `allowed=true` decision from when the category was free could
      // persist for 120s and let the user bypass the new paywall.
      if (_categoriesLoaded) {
        for (final newCat in cats) {
          // Find the old version of this category to compare premium status.
          CategoryModel? oldCat;
          for (final c in _categories) {
            if (c.id == newCat.id) { oldCat = c; break; }
          }
          if (oldCat != null &&
              (oldCat.isPremium != newCat.isPremium ||
               oldCat.premiumPrice != newCat.premiumPrice)) {
            AccessService.clearCacheForCategory(newCat.id);
          }
        }
      }
      _lastCategoriesSig = newSig;
      setState(() {
        _categories = cats;
        _categoriesLoaded = true;
      });
    });
    // Reactivity: listen to AuthProvider so preferred categories refresh
    // live when the user changes them from Profile > My Categories (which
    // is in a different tab and would otherwise leave Home stale until a
    // restart). Post-frame so Provider is initialized before we read it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _auth = Provider.of<AuthProvider>(context, listen: false);
      _auth!.addListener(_onAuthChanged);
    });
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    _categoriesSub?.cancel();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoScroll() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_bannerController.hasClients) return;
      if (_bannerCount <= 1) return; // nothing to rotate through
      // WRAP with modulo so we don't try to animate past the last banner
      // (the old `+1` without modulo caused animateToPage to target an
      // out-of-bounds index, which left the carousel stuck on the last
      // banner — the "banner auto change hoi na" bug).
      final nextPage = (_currentBannerPage + 1) % _bannerCount;
      _bannerController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Brand emerald AppBar — gives the first screen a strong identity.
        // Previously the AppBar used the default theme background (light stone)
        // while the icons/title were hardcoded white, which made them invisible.
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(Icons.school_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Text(
              'ExamVault',
              style: AppFonts.style(
                size: 20,
                weight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          // Global search — opens a full-screen SearchScreen that searches
          // across categories, subjects, tests and current affairs.
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            tooltip: tr(context, 'search'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: Colors.white,
                ),
                tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                onPressed: () => themeProvider.toggleTheme(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            tooltip: tr(context, 'settings_notifications'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Streams auto-refresh; this is just for the pull-to-refresh UX.
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          // RepaintBoundary isolates the scrollable content's layer so that
          // repainting during scroll doesn't bleed into the AppBar / bottom
          // nav. This reduces the visible "flash" the user reported when
          // scrolling to the bottom.
          child: RepaintBoundary(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBannerCarousel(),
              const SizedBox(height: AppTheme.spaceLg),
              _buildGuestBanner(),
              const SizedBox(height: AppTheme.spaceXl),
              // ===== Quick actions + All Free Tests (stacked) =====
              // SECTION 1: "All Free Tests" full-width banner button (blue
              // gradient CTA). SECTION 2: the 5 quick-action tiles in a single
              // 5-column row below it. Stacking (instead of side-by-side)
              // avoids the old 3+2 tile wrap that looked uneven in dark mode.
              _buildQuickActionsRow(),
              const SizedBox(height: AppTheme.spaceXl),
              _buildAnnouncementsTicker(),
              const SizedBox(height: AppTheme.spaceXl),
              _buildCategoriesSection(),
              const SizedBox(height: AppTheme.spaceXl),
              _buildPopularSubjects(),
              const SizedBox(height: AppTheme.spaceXl),
              _buildUpcomingExamsPreview(),
              const SizedBox(height: AppTheme.spaceXl),
              _buildCurrentAffairs(),
              const SizedBox(height: AppTheme.spaceXl),
              _buildPremiumBanner(),
              const SizedBox(height: AppTheme.spaceXl),
            ],
          ),
          ),  // RepaintBoundary
        ),  // SingleChildScrollView
      ),  // RefreshIndicator
    );
  }

  // ==================== BANNER CAROUSEL ====================
  Widget _buildBannerCarousel() {
    return StreamBuilder<List<BannerModel>>(
      stream: _bannersStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // no banners → hide carousel
        }
        final banners = snapshot.data!;
        // Track the count so the auto-rotate timer can wrap with modulo.
        // (Updated via addPostFrameCallback so we don't call setState during
        // build.)
        if (_bannerCount != banners.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _bannerCount = banners.length);
          });
        }
        return Column(
          children: [
            SizedBox(
              height: 160,
              child: PageView.builder(
                controller: _bannerController,
                itemCount: banners.length,
                onPageChanged: (i) => setState(() => _currentBannerPage = i),
                itemBuilder: (context, index) {
                  final b = banners[index];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      // Whole-banner tap → run the primary button's action
                      // (if any). The two explicit buttons below handle their
                      // own taps; this is a convenience so tapping anywhere
                      // on the image still does something useful.
                      final primary = b.primaryButton;
                      if (primary != null && primary.isSet) {
                        await runActionButton(context, primary);
                        return;
                      }
                      // No primary button — fall back to legacy link field.
                      if (b.link == null || b.link!.isEmpty) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('This banner has no action set.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      final uri = Uri.tryParse(b.link!);
                      if (uri == null) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Invalid banner link: ${b.link}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      try {
                        final launched = await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                        if (!launched) {
                          await launchUrl(uri,
                              mode: LaunchMode.inAppBrowserView);
                        }
                      } catch (_) {
                        try {
                          await launchUrl(uri);
                        } catch (_) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not open link.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        boxShadow: AppTheme.softShadow2,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: b.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: Colors.grey.shade200,
                                child: const Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: AppTheme.primaryColor,
                                child: const Center(
                                  child: Icon(Icons.broken_image, color: Colors.white, size: 40),
                                ),
                              ),
                            ),
                            // Gradient overlay for text legibility
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.6),
                                    Colors.transparent,
                                  ],
                                  stops: const [0, 0.5],
                                ),
                              ),
                            ),
                            // LIVE badge (top-left) — pulsing red dot + "LIVE"
                            // label, matching the admin preview so users see
                            // the same "live" indicator the admin sees.
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.errorColor.withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spaceXs),
                                    Text(
                                      'LIVE',
                                      style: AppFonts.style(
                                        color: Colors.white,
                                        size: 9,
                                        weight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Text + CTA buttons (up to 2, each independently
                            // configured by the admin as external link OR
                            // in-app screen). Tapping a button runs only that
                            // button's action; tapping elsewhere on the banner
                            // runs the primary button's action (see onTap above).
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    b.title,
                                    style: AppFonts.style(
                                      color: Colors.white,
                                      size: 16,
                                      weight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (b.subtitle != null && b.subtitle!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      b.subtitle!,
                                      style: AppFonts.style(
                                        color: Colors.white.withOpacity(0.9),
                                        size: 11,
                                        height: 1.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (b.primaryButton != null ||
                                      b.secondaryButton != null) ...[
                                    const SizedBox(height: AppTheme.spaceSm),
                                    Row(
                                      children: [
                                        if (b.primaryButton != null &&
                                            b.primaryButton!.isSet)
                                          Expanded(
                                            child: _buildBannerButton(
                                              context,
                                              b.primaryButton!,
                                              isPrimary: true,
                                            ),
                                          ),
                                        if (b.primaryButton != null &&
                                            b.primaryButton!.isSet &&
                                            b.secondaryButton != null &&
                                            b.secondaryButton!.isSet) ...[
                                          const SizedBox(width: AppTheme.spaceSm),
                                          Expanded(
                                            child: _buildBannerButton(
                                              context,
                                              b.secondaryButton!,
                                              isPrimary: false,
                                            ),
                                          ),
                                        ] else if (b.secondaryButton != null &&
                                            b.secondaryButton!.isSet) ...[
                                          // Only secondary set (no primary) —
                                          // show it full width.
                                          Expanded(
                                            child: _buildBannerButton(
                                              context,
                                              b.secondaryButton!,
                                              isPrimary: false,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            // Page indicator
            if (banners.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(banners.length, (i) {
                  final isActive = i == _currentBannerPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                  );
                }),
              ),
          ],
        );
      },
    );
  }

  /// Renders a single CTA button inside a banner. Primary buttons are solid
  /// white (high contrast against the banner image); secondary buttons are
  /// translucent so the two are visually distinct. Each button runs only its
  /// own [ActionButton] on tap — the outer banner GestureDetector does NOT
  /// receive these taps because Material InkWell / GestureDetector here wins
  /// the hit-test.
  Widget _buildBannerButton(
    BuildContext context,
    ActionButton button, {
    required bool isPrimary,
  }) {
    final label = button.isSet ? button.label : '';
    if (label.isEmpty) return const SizedBox.shrink();
    final btn = Material(
      color: isPrimary ? Colors.white : Colors.white.withOpacity(0.22),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => runActionButton(context, button),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.style(
              size: 11,
              weight: FontWeight.w700,
              color: isPrimary ? AppTheme.primaryColor : Colors.white,
            ),
          ),
        ),
      ),
    );
    return btn;
  }

  /// Slim banner shown only in guest mode. Reminds the user they're browsing
  /// without an account and gives a one-tap path to sign in. Tapping it opens
  /// the login screen; after login the user returns to the app with full
  /// access to whatever they've purchased.
  Widget _buildGuestBanner() {
    final auth = Provider.of<AuthProvider>(context);
    if (!auth.isGuest) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.4)),
        boxShadow: AppTheme.softShadow1,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline_rounded,
                size: 18, color: AppTheme.accentColor),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: L10nText(
              'home_guestMsg',
              style: AppFonts.style(
                size: 12,
                weight: FontWeight.w500,
                color: isDark ? Colors.grey.shade100 : Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppTheme.accentColor,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: L10nText(
              'home_signIn',
              style: AppFonts.style(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppTheme.accentColor),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1);
  }

  /// Two stacked full-width sections:
  ///   SECTION 1 — "All Free Tests" full-width banner button (blue CTA).
  ///   SECTION 2 — the 5 quick-action tiles in a single 5-column row.
  /// Previously these were squeezed side-by-side (button on the left took
  /// ~25% and the grid took ~75%), which forced the 5 tiles into a 3+2 wrap
  /// that looked uneven — especially in dark mode. Stacking them gives the
  /// button the full width and lets all 5 tiles sit in one clean row.
  Widget _buildQuickActionsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // SECTION 1 — "All Free Tests" full-width banner button.
        _buildAllFreeTestsButton(),
        const SizedBox(height: AppTheme.spaceSm),
        // SECTION 2 — 5 quick-action tiles in a single 5-column row.
        _buildQuickActionsGrid(),
      ],
    );
  }

  /// SECTION 1 — the "All Free Tests" button, now a full-width horizontal
  /// banner. Blue gradient background, gift icon on the left, a "FREE" pill
  /// + label in the middle, and an arrow on the right. Tapping opens the
  /// FreeTestsScreen.
  Widget _buildAllFreeTestsButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FreeTestsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd,
          vertical: AppTheme.spaceSm + 2,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppTheme.brandGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.softShadow1,
        ),
        child: Row(
          children: [
            // Gift icon on the left (white, in a translucent rounded square).
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            // "FREE" pill + label.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      'FREE',
                      style: AppFonts.style(
                        size: 9,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  L10nText(
                    'home_allFreeTests',
                    style: AppFonts.style(
                      size: 14,
                      weight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spaceXs),
            // Arrow on the right (white).
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 80.ms, duration: 350.ms)
        .slideY(begin: 0.12);
  }

  /// SECTION 2 — the 5 quick-action tiles in a single 5-column row that
  /// fills the full width. All five tiles now sit on one row (no 3+2 wrap),
  /// which keeps the layout even in both light and dark mode.
  Widget _buildQuickActionsGrid() {
    // Curated palette aligned with the Assam theme — NO raw color literals.
    // Daily Quiz  → amber (accentColor)
    // Mock Tests  → emerald (primaryColor)
    // Upcoming    → success green
    // Current Affairs → violet (category accent — not a brand color)
    // Bookmarks   → warning orange
    final actions = [
      _QuickAction(
        icon: Icons.quiz_rounded,
        labelKey: 'home_dailyQuiz',
        color: AppTheme.accentColor,
        route: _QuickRoute.quiz,
      ),
      _QuickAction(
        icon: Icons.assignment_rounded,
        labelKey: 'home_quickMock',
        color: AppTheme.primaryColor,
        route: _QuickRoute.mock,
      ),
      _QuickAction(
        icon: Icons.event_available_rounded,
        labelKey: 'home_quickUpcoming',
        color: AppTheme.successColor,
        route: _QuickRoute.upcoming,
      ),
      _QuickAction(
        icon: Icons.newspaper_rounded,
        labelKey: 'home_currentAffairs',
        color: AppTheme.primaryColor, // Brand teal (violet was off-brand)
        route: _QuickRoute.current,
      ),
      _QuickAction(
        icon: Icons.bookmark_rounded,
        labelKey: 'home_quickBookmarks',
        color: AppTheme.warningColor,
        route: _QuickRoute.bookmarks,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: AppTheme.spaceSm,
        crossAxisSpacing: AppTheme.spaceSm,
        // 0.75 (taller tiles) instead of 0.82 — prevents vertical overflow
        // on 360px-and-below phones where 5 columns leave each tile ~52-59px
        // wide. With the compact icon (34) + 4px padding below, content needs
        // ~64px which fits the ~68-79px tile height on screens down to 320px.
        childAspectRatio: 0.75,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return _buildQuickActionCard(action)
            .animate()
            .fadeIn(delay: (80 + index * 40).ms, duration: 350.ms)
            .slideY(begin: 0.12);
      },
    );
  }

  Widget _buildQuickActionCard(_QuickAction action) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateQuickAction(action.route),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceXs),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardColor : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.softShadow1,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    action.color.withOpacity(0.18),
                    action.color.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                action.icon,
                color: action.color,
                size: 18,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXs),
            // FittedBox auto-shrinks the label if the tile is too narrow,
            // so "Current Affairs" never overflows on small phones.
            Flexible(
              child: L10nText(
                action.labelKey,
                style: AppFonts.style(
                  size: 9,
                  weight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade100 : Colors.grey.shade800,
                  height: 1.15,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateQuickAction(_QuickRoute route) {
    switch (route) {
      case _QuickRoute.quiz:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const DailyQuizScreen()));
        break;
      case _QuickRoute.mock:
        // Open the Test Series screen so users can browse ALL test types
        // (Mock, Previous Year, Daily Quiz, Practice, Subject-wise) — not
        // just upcoming exams.
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const TestSeriesScreen()));
        break;
      case _QuickRoute.current:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CurrentAffairsScreen()));
        break;
      case _QuickRoute.upcoming:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const UpcomingExamsScreen()));
        break;
      case _QuickRoute.bookmarks:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const BookmarksScreen()));
        break;
    }
  }

  // ==================== ANNOUNCEMENTS TICKER ====================
  Widget _buildAnnouncementsTicker() {
    return StreamBuilder<List<AnnouncementModel>>(
      stream: _announcementsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final list = snapshot.data!;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AnnouncementsScreen()));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm + 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border:
                  Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              boxShadow: AppTheme.softShadow1,
            ),
            child: Row(
              children: [
                // LIVE pulsing badge — the "live" indicator the user saw in
                // the admin preview but was missing in the user app.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: AppTheme.spaceXs - 1),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm - 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.errorColor.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceXs - 1),
                      Text(
                        'LIVE',
                        style: AppFonts.style(
                          color: Colors.white,
                          size: 9,
                          weight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm - 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.campaign_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: AppTheme.spaceXs),
                      L10nText(
                        'home_updates',
                        style: AppFonts.style(
                          color: Colors.white,
                          size: 11,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm + 2),
                Expanded(
                  child: _MarqueeText(
                    texts: list
                        .map((a) => lc(context, a.title, a.titleAs))
                        .toList(),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.primaryColor, size: 18),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.06);
      },
    );
  }

  Future<void> _loadSelectedCategoryIds() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ids = await CategoryPreferenceService.getSelectedCategoryIds(auth.user);
    if (!mounted) return;
    // Skip setState if nothing changed — avoids unnecessary rebuilds when
    // AuthProvider notifies for unrelated reasons (premium, streak, etc.).
    if (_listEquals(ids, _selectedCategoryIds)) return;
    setState(() => _selectedCategoryIds = ids);
  }

  /// AuthProvider listener — fires when the user's preferences change
  /// (e.g. after Profile > My Categories saves a new selection). Re-fetches
  /// preferred ids so every section on Home reflects the new selection
  /// without a restart. Also fires on premium/streak updates, but
  /// _loadSelectedCategoryIds guards against no-op rebuilds.
  void _onAuthChanged() {
    if (!mounted) return;
    _loadSelectedCategoryIds();
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Whether [categoryId] matches any of the user's preferred categories.
  /// Handles the case where subject.categoryId might hold a name or slug
  /// instead of the doc id (mirror of all_subjects_screen's robust matching).
  /// Returns true (no filter) when the user hasn't selected any categories.
  bool _isPreferredCategory(String? categoryId) {
    if (_selectedCategoryIds.isEmpty) return true; // no filter active
    if (categoryId == null || categoryId.isEmpty) return false;
    if (_selectedCategoryIds.contains(categoryId)) return true;
    // Fallback: match against category names/slugs (subject.categoryId may
    // hold a slug/name due to FirestoreService.getSubjects fallback matching).
    for (final catId in _selectedCategoryIds) {
      final cat = _categories.firstWhere(
        (c) => c.id == catId,
        orElse: () => CategoryModel.empty(),
      );
      if (cat.name == categoryId || cat.slug == categoryId) return true;
    }
    return false;
  }

  Future<void> _openManageCategories() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CategorySelectionScreen(isOnboarding: false),
      ),
    );
    if (changed == true) {
      _loadSelectedCategoryIds();
    }
  }

  /// _categories filtered down to the user's selection. Falls back to the
  /// full list when nothing is selected (guest/skip) — this feature only
  /// narrows the view, it never hides categories the user hasn't chosen to
  /// filter by.
  List<CategoryModel> get _displayedCategories {
    if (_selectedCategoryIds.isEmpty) return _categories;
    final filtered = _categories
        .where((c) => _selectedCategoryIds.contains(c.id))
        .toList();
    // If the saved IDs no longer match any live category (deleted by admin),
    // don't show an empty grid — fall back to everything.
    return filtered.isEmpty ? _categories : filtered;
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            L10nText(
              'home_categories',
              style: AppFonts.style(
                size: 18,
                weight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "My Categories" — lets the user revisit their onboarding
                // selection at any time, so the filter below isn't permanent.
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.tune,
                      size: 20,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6)),
                  tooltip: 'My Categories',
                  onPressed: _openManageCategories,
                ),
                TextButton(
                  // Navigate to the All Categories screen (full grid of all exam
                  // categories). Previously this opened All Subjects, which was
                  // the wrong destination — users expected more categories.
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AllCategoriesScreen()),
                    );
                  },
                  child: L10nText(
                    'viewAll',
                    style: AppFonts.style(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: AppTheme.spaceMd),
        // _categories is kept fresh by _categoriesSub in initState.
        // No StreamBuilder here — having both a subscription AND a StreamBuilder
        // created two Firestore listeners and caused every update to rebuild
        // the widget twice.
        if (!_categoriesLoaded)
          _buildShimmerGrid()
        else if (_categories.isEmpty)
          _buildSectionEmpty(tr(context, 'home_noCategories'))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppTheme.spaceMd,
              crossAxisSpacing: AppTheme.spaceMd,
              childAspectRatio: 0.82,
            ),
            itemCount: _displayedCategories.length,
            itemBuilder: (context, index) {
              return _buildCategoryCard(_displayedCategories[index])
                  .animate()
                  .fadeIn(delay: (120 + index * 50).ms, duration: 400.ms)
                  .slideY(begin: 0.08);
            },
          ),
      ],
    );
  }

  Widget _buildCategoryCard(CategoryModel category) {
    // Per-category color + gradient — gives each exam its own signature look.
    final color = AppTheme.colorFor(category.name);
    // Use Selector so only the lock state (a single bool) is watched from
    // AuthProvider. Without this, EVERY notifyListeners() call (including
    // unrelated auth events) would rebuild every category card in the grid,
    // making the app noticeably slow after a premium purchase.
    return Selector<AuthProvider, bool>(
      selector: (_, auth) =>
          category.isPremium && !auth.hasCategoryAccess(category.id),
      builder: (context, categoryLocked, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return GestureDetector(
          // CRITICAL: opaque hit-testing so taps register anywhere on the
          // card — not just on painted pixels. Without this, transparent
          // areas of the Stack (edges, gaps in dark mode) swallow taps and
          // the user thinks the category button is "not clicking".
          // This matches the Upcoming Exam (Material+InkWell) and Current
          // Affairs (GestureDetector+opaque) cards which DO click reliably.
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            if (categoryLocked) {
              _showCategoryPaywall(context, category);
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryDetailScreen(category: category),
              ),
            );
          },
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardColor : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: AppTheme.softShadow2,
                  border: Border.all(
                      color: color.withOpacity(0.08), width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Category-tinted icon tile (gradient tint).
                    // Wrapped in Hero so it flies to CategoryDetailScreen's
                    // header on tap (tag: 'category-icon-<id>').
                    Hero(
                      tag: 'category-icon-${category.id}',
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withOpacity(0.18),
                              color.withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                              color: color.withOpacity(0.15), width: 1),
                        ),
                        child: Center(
                          child: Text(
                            category.icon ?? '📚',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    // Fixed-height name block so every card looks the SAME
                    // size regardless of name length. Short names ("LIC",
                    // "SSC") center in the 32px box; long names ("Maharashtra",
                    // "Assam APSC") wrap to 2 lines and clip with ellipsis.
                    SizedBox(
                      height: 32,
                      child: Center(
                        child: Text(
                          lc(context, category.name, category.nameAs),
                          style: AppFonts.style(
                            size: 12,
                            weight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXs),
                    // Subject-count badge with category tint.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSm, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        '${category.subjectCount} ${tr(context, 'category_subjects')}',
                        style: AppFonts.style(
                          size: 10,
                          weight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                    // Premium price hint under the subject count for locked cats.
                    if (categoryLocked && category.premiumPrice > 0) ...[
                      const SizedBox(height: AppTheme.spaceXs),
                      Text(
                        '₹${category.premiumPrice}',
                        style: AppFonts.style(
                          size: 11,
                          weight: FontWeight.w700,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Crown / lock badge for premium categories (top-right corner).
              if (category.isPremium)
                Positioned(
                  top: AppTheme.spaceXs + 2,
                  right: AppTheme.spaceXs + 2,
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spaceXs),
                    decoration: BoxDecoration(
                      gradient: categoryLocked
                          ? const LinearGradient(
                              colors: AppTheme.accentGradientColors)
                          : null,
                      color: categoryLocked
                          ? null
                          : AppTheme.accentColor.withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                      boxShadow: categoryLocked
                          ? [
                              BoxShadow(
                                color: AppTheme.accentColor
                                    .withOpacity(0.4),
                                blurRadius: 6,
                                spreadRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      categoryLocked
                          ? Icons.lock_rounded
                          : Icons.workspace_premium_rounded,
                      size: 12,
                      color: categoryLocked
                          ? Colors.white
                          : AppTheme.accentColor,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Real paywall for premium categories. Shown when a non-premium user taps
  /// a premium category. Offers two paths: "Unlock this exam (₹X)" (Exam Pack
  /// purchase via server-side-verified Razorpay) and "Go Premium" (full
  /// subscription). This is the REAL lock — without it, users could browse
  /// premium categories freely.
  void _showCategoryPaywall(BuildContext context, CategoryModel category) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final isGuest = auth.isGuest;
    final canBuyExamPack = category.premiumPrice > 0;
    final localizedName = lc(context, category.name, category.nameAs);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock,
                    size: 48, color: AppTheme.accentColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'Premium Category',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isGuest
                    ? 'Sign in to unlock "$localizedName" and all its tests.'
                    : canBuyExamPack
                        ? 'Unlock "$localizedName" and all its tests for ₹${category.premiumPrice}, or upgrade to Premium for unlimited access.'
                        : 'Subscribe to Premium to unlock "$localizedName" and all its tests.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '✓ All mock tests in this exam\n✓ Detailed Solutions\n✓ Performance Analytics',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          actions: [
            if (isGuest) ...[
              // GUEST CTA — must sign in before purchasing.
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In to Unlock'),
                ),
              ),
            ] else ...[
              if (canBuyExamPack)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: user == null
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _startExamPackFromHome(context, category, auth);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.lock_open),
                    label: Text(
                        'Unlock this exam (₹${category.premiumPrice})'),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // FIXED: clear stale access cache + force rebuild when user returns from premium.
                    Navigator.pushNamed(context, '/premium').then((_) {
                      if (mounted) {
                        AccessService.clearCache();
                        setState(() {});
                      }
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentColor,
                    side: const BorderSide(color: AppTheme.accentColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('Go Premium'),
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Maybe later'),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Starts an Exam Pack purchase from the home screen paywall dialog. Shows
  /// loading indicators during the two network steps (createOrder + verify)
  /// so the user always knows what's happening — fixes "app hang hoye geche"
  /// when tapping "Unlock this exam" with no feedback. On server-verified
  /// success, clears the access cache + refreshes the user + shows a prominent
  /// success dialog, then opens the category detail screen.
  void _startExamPackFromHome(
    BuildContext context,
    CategoryModel category,
    AuthProvider auth,
  ) {
    final user = auth.user;
    if (user == null) return;

    final progress = PaymentProgressDialog();
    // `cancelled` only suppresses *error* snackbars after the user explicitly
    // cancelled. It does NOT block onSuccess — a payment that actually
    // succeeded must always be honoured.
    bool cancelled = false;

    void showCheckPurchasesMessage() {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: const Text(
            'Payment is taking longer than expected. Check "My Purchases" to see if it succeeded.',
          ),
          backgroundColor: AppTheme.warningColor,
          action: SnackBarAction(
            label: 'My Purchases',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) {
                Navigator.pushNamed(context, '/my-purchases');
              }
            },
          ),
        ),
      );
    }

    RazorpayService.startExamPackPurchase(
      userId: user.id,
      userName: user.name,
      userEmail: user.email ?? 'user@examvault.com',
      userPhone: user.phoneNumber ?? '9999999999',
      categoryId: category.id,
      categoryName: category.name,
      amount: category.premiumPrice,
      onPreparing: () {
        if (cancelled) return;
        progress.show(
          context,
          message: 'Preparing payment...',
          cancellable: true,
          onCancel: () => cancelled = true,
          onSafetyTimeout: showCheckPurchasesMessage,
        );
      },
      onCheckoutOpened: () {
        progress.dismiss();
      },
      onVerifying: () {
        if (cancelled) return;
        progress.show(
          context,
          message: 'Verifying payment...',
          cancellable: true,
          cancelLabel: 'Check My Purchases',
          safetyTimeout: const Duration(seconds: 60),
          onCancel: () {
            cancelled = true;
            showCheckPurchasesMessage();
          },
          onSafetyTimeout: showCheckPurchasesMessage,
        );
      },
      onSuccess: (response) {
        // ALWAYS process a successful payment — even if the user dismissed
        // the dialog, the payment went through and the exam pack must be
        // unlocked.
        progress.dismiss();
        // Optimistically cache a positive access decision so the
        // CategoryDetailScreen's _checkAccess() returns instantly. The
        // background /verify might not have completed yet.
        AccessService.markExamPackPurchased(category.id);
        // FIXED: update local user model immediately so the category card
        // unlocks without waiting for a loadUserData() round-trip.
        auth.addPurchasedCategory(category.id);
        auth.loadUserData();
        if (!mounted) return;
        // Show a PROMINENT success dialog (not a subtle snackbar). The user
        // taps "Open Exam" to proceed. This fixes "payment er por kichui hoi
        // na" — the user now gets clear, unmissable feedback.
        PaymentSuccessDialog.show(
          context,
          itemName: lc(context, category.name, category.nameAs),
          amount: category.premiumPrice,
          actionLabel: 'Open Exam',
          paymentId: response.paymentId,
        ).then((shouldOpen) {
          if (!mounted) return;
          // Always open the category so the user can start browsing —
          // regardless of whether they tapped "Open Exam" or "Later", the
          // exam pack is unlocked now.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryDetailScreen(category: category),
            ),
          );
        });
      },
      onError: (response) {
        progress.dismiss();
        // If the user explicitly cancelled, don't show a scary "Payment
        // failed" message — they already know.
        if (cancelled) return;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(response.message ?? 'Payment failed. Please try again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
    );
  }

  Widget _buildPopularSubjects() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            L10nText(
              'home_popular',
              style: AppFonts.style(
                size: 18,
                weight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            // Wire up the 'View All' button to the All Subjects screen where
            // the user can browse every subject, filter by category, and search.
            // Previously this wrongly opened the UpcomingExamsScreen — fixed.
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AllSubjectsScreen()),
                );
              },
              child: L10nText(
                'viewAll',
                style: AppFonts.style(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppTheme.primaryColor),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: AppTheme.spaceMd),
        StreamBuilder<List<SubjectModel>>(
          stream: _subjectsStream,
          builder: (context, snapshot) {
            // BUGFIX (offline): Show cached data IMMEDIATELY if available,
            // even if the stream is still "waiting" to re-validate against
            // the server. Previously the check order was
            //   if (waiting) shimmer; if (error) error; if (!hasData) empty;
            // which meant that on every stream re-subscription (e.g. after
            // the parent rebuilds, or after a brief network hiccup) the
            // section flashed a shimmer even though cached data was sitting
            // right there in snapshot.data. Reordering to check hasData
            // first means the user sees content instantly from the Firestore
            // offline cache, and only sees shimmer/error on the VERY FIRST
            // load when no cache exists yet.
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              var subjects = snapshot.data!;
              // Filter by preferred categories (with fallback to all when
              // the filtered list is empty — never show an empty preview).
              if (_selectedCategoryIds.isNotEmpty) {
                final filtered = subjects
                    .where((s) => _isPreferredCategory(s.categoryId))
                    .toList();
                if (filtered.isNotEmpty) subjects = filtered;
              }
              return SizedBox(
                height: 168,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: AppTheme.spaceMd),
                  itemCount: subjects.length,
                  itemBuilder: (context, index) {
                    return _buildSubjectCard(subjects[index])
                        .animate()
                        .fadeIn(delay: (120 + index * 60).ms, duration: 400.ms)
                        .slideX(begin: 0.1);
                  },
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerList();
            }
            // Surface stream errors instead of silently showing "No subjects
            // available". This is the same root cause as the category detail
            // screen — if the subjects stream errors out, the user sees an
            // empty section and thinks "Start Now is not clickable".
            if (snapshot.hasError) {
              return _buildSectionError(tr(context, 'error_connectionDesc'));
            }
            return _buildSectionEmpty(tr(context, 'home_noSubjects'));
          },
        ),
      ],
    );
  }

  Widget _buildSubjectCard(SubjectModel subject) {
    // FIXED: resolve authoritative category id so exam-pack access check works.
    final matchedCategory = _categories.firstWhere(
      (c) =>
          c.id == subject.categoryId ||
          c.name == subject.categoryId ||
          c.slug == subject.categoryId,
      orElse: () => CategoryModel.empty(),
    );
    final authCategoryId = matchedCategory.id.isNotEmpty
        ? matchedCategory.id
        : subject.categoryId;
    // Category-tinted gradient — falls back to brand emerald when no match.
    final gradient = matchedCategory.id.isNotEmpty
        ? AppTheme.gradientFor(matchedCategory.name)
        : AppTheme.brandGradient;
    // Localized display strings (computed once to avoid repeated Provider
    // lookups inside this build).
    final localizedName = lc(context, subject.name, subject.nameAs);
    final localizedDescription =
        lc(context, subject.description ?? '', subject.descriptionAs);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TestListScreen(
              subject: subject,
              categoryId: authCategoryId,
            ),
          ),
        );
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: AppTheme.spaceMd),
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.softShadow2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      subject.icon ?? '📚',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    '${subject.testCount} ${tr(context, 'subject_tests')}',
                    style: AppFonts.style(
                        color: Colors.white,
                        size: 10,
                        weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedName,
                  style: AppFonts.style(
                    color: Colors.white,
                    size: 16,
                    weight: FontWeight.w700,
                    height: 1.25,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  localizedDescription,
                  style: AppFonts.style(
                    color: Colors.white.withOpacity(0.9),
                    size: 11,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            // "Start Now" CTA — the whole card is tappable, this is a visual
            // affordance. Pill shape with subtle border so it reads as a button.
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceXs + 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  L10nText(
                    'startNow',
                    style: AppFonts.style(
                      color: Colors.white,
                      size: 12,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceXs),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== UPCOMING EXAMS PREVIEW ====================
  Widget _buildUpcomingExamsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            L10nText(
              'home_upcoming',
              style: AppFonts.style(
                size: 18,
                weight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const UpcomingExamsScreen()));
              },
              child: L10nText(
                'viewAll',
                style: AppFonts.style(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppTheme.primaryColor),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: AppTheme.spaceMd),
        StreamBuilder<List<UpcomingExamModel>>(
          stream: _upcomingExamsStream,
          builder: (context, snapshot) {
            // BUGFIX (offline): check hasData FIRST so cached data shows
            // instantly from the Firestore offline cache instead of
            // flashing a shimmer on every stream re-validation.
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              var exams = snapshot.data!;
              // Filter by preferred categories (with fallback to all when
              // the filtered list is empty — never show an empty preview).
              if (_selectedCategoryIds.isNotEmpty) {
                final filtered = exams
                    .where((e) =>
                        e.categoryId != null &&
                        _selectedCategoryIds.contains(e.categoryId))
                    .toList();
                if (filtered.isNotEmpty) exams = filtered;
              }
              return Column(
                children: List.generate(exams.length, (i) {
                  return _buildUpcomingExamMiniCard(exams[i])
                      .animate()
                      .fadeIn(delay: (120 + i * 60).ms, duration: 400.ms)
                      .slideY(begin: 0.05);
                }),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerList();
            }
            if (snapshot.hasError) {
              return _buildSectionError(tr(context, 'error_connectionDesc'));
            }
            return _buildSectionEmpty(
              tr(context, 'home_noUpcoming'),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UpcomingExamsScreen()));
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildUpcomingExamMiniCard(UpcomingExamModel e) {
    final days = e.daysRemaining;
    final isPast = days < 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Accent color: grey for past, red for ≤30 days, emerald otherwise.
    final accentColor = isPast
        ? Colors.grey
        : days <= 30
            ? AppTheme.errorColor
            : AppTheme.primaryColor;
    // Localized display strings (computed once to avoid repeated Provider
    // lookups inside this build).
    final localizedName = lc(context, e.name, e.nameAs);
    final localizedOrganization =
        lc(context, e.organization ?? '', e.organizationAs);
    // Tapping a mini exam card now opens that specific exam's detail page
    // (UpcomingExamDetailScreen) instead of the full "Upcoming Exams" list —
    // so each card is independently clickable. The "View All" header button
    // still opens the full list. Using Material+InkWell so the tap has a
    // visible ripple. The inner "Apply" chip keeps its own GestureDetector so
    // it can launch the URL directly without leaving the home screen.
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm + 4),
      child: Material(
        color: isDark ? AppTheme.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        UpcomingExamDetailScreen(exam: e)));
          },
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border(
                left: BorderSide(
                  color: accentColor,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                // Calendar-style date badge — day + month abbreviation.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${e.examDate.day}',
                        style: AppFonts.style(
                            size: 16,
                            weight: FontWeight.w700,
                            color: accentColor,
                            height: 1.0),
                      ),
                      Text(
                        _monthName(e.examDate.month),
                        style: AppFonts.style(
                            size: 9,
                            weight: FontWeight.w700,
                            color: accentColor,
                            height: 1.0,
                            letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizedName,
                        style: AppFonts.style(
                            size: 13,
                            weight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.25),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.organization != null && e.organization!.isNotEmpty
                            ? localizedOrganization
                            : '${e.examDate.day}/${e.examDate.month}/${e.examDate.year}',
                        style: AppFonts.style(
                            size: 11,
                            color: Colors.grey.shade600,
                            height: 1.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Apply quick-action chip — only when the exam has an apply
                // URL. Tapping it launches the URL directly (NOT navigation to
                // the full list). Hit-testing gives the tap to the innermost
                // gesture handler, so the chip's GestureDetector wins over the
                // outer InkWell; tapping anywhere else still opens the list.
                if (e.applyUrl != null && e.applyUrl!.isNotEmpty) ...[
                  const SizedBox(width: AppTheme.spaceSm),
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.tryParse(e.applyUrl!);
                      if (uri == null) return;
                      try {
                        final ok = await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                        if (!ok) {
                          await launchUrl(uri,
                              mode: LaunchMode.inAppBrowserView);
                        }
                      } catch (_) {}
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSm + 2,
                          vertical: AppTheme.spaceXs + 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_in_new_rounded,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 3),
                          L10nText(
                            'home_apply',
                            style: AppFonts.style(
                              size: 11,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSm,
                      vertical: AppTheme.spaceXs + 1),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    isPast
                        ? '${-days} ${tr(context, 'home_daysAgo')}'
                        : '$days ${tr(context, 'home_days')}',
                    style: AppFonts.style(
                      size: 11,
                      weight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentAffairs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            L10nText(
              'home_currentAffairs',
              style: AppFonts.style(
                size: 18,
                weight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CurrentAffairsScreen()),
                );
              },
              child: L10nText(
                'viewAll',
                style: AppFonts.style(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppTheme.primaryColor),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: AppTheme.spaceMd),
        StreamBuilder<List<CurrentAffairModel>>(
          stream: _currentAffairsStream,
          builder: (context, snapshot) {
            // BUGFIX (offline): check hasData FIRST so cached data shows
            // instantly from the Firestore offline cache instead of
            // flashing a shimmer on every stream re-validation.
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              var affairs = snapshot.data!;
              // Filter by preferred categories (with fallback to all when
              // the filtered list is empty — CurrentAffairModel.categoryId
              // is optional and may be null on legacy docs).
              if (_selectedCategoryIds.isNotEmpty) {
                final filtered = affairs
                    .where((a) =>
                        a.categoryId != null &&
                        _selectedCategoryIds.contains(a.categoryId))
                    .toList();
                if (filtered.isNotEmpty) affairs = filtered;
              }
              return Column(
                children: List.generate(affairs.length, (i) {
                  return _buildCurrentAffairCard(affairs[i])
                      .animate()
                      .fadeIn(delay: (120 + i * 60).ms, duration: 400.ms)
                      .slideY(begin: 0.05);
                }),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerList();
            }
            if (snapshot.hasError) {
              return _buildSectionError(tr(context, 'error_connectionDesc'));
            }
            return _buildSectionEmpty(
              tr(context, 'home_noCurrentAffairs'),
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CurrentAffairsScreen()));
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCurrentAffairCard(CurrentAffairModel affair) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        affair.isImportant ? AppTheme.accentColor : AppTheme.primaryColor;
    // Localized display strings (computed once to avoid repeated Provider
    // lookups inside this build).
    final localizedTitle = lc(context, affair.title, affair.titleAs);
    final localizedSummary = lc(context, affair.summary, affair.summaryAs);
    // Tapping a current-affair card now opens that specific affair's detail
    // page (CurrentAffairDetailScreen) instead of the full list — so each card
    // is independently clickable. "View All" header button still opens the
    // full list with filters + bottom-sheet detail.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    CurrentAffairDetailScreen(affair: affair)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardColor : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border(
            left: BorderSide(
              color: accent,
              width: 4,
            ),
          ),
          boxShadow: AppTheme.softShadow1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Date pill tinted with the accent color.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSm,
                      vertical: AppTheme.spaceXs),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    '${affair.date.day} ${_monthName(affair.date.month)}',
                    style: AppFonts.style(
                      size: 11,
                      color: accent,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                if (affair.isImportant) ...[
                  const SizedBox(width: AppTheme.spaceSm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSm, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 10, color: AppTheme.accentColor),
                        const SizedBox(width: 3),
                        L10nText(
                          'home_important',
                          style: AppFonts.style(
                            size: 10,
                            color: AppTheme.accentColor,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  affair.category,
                  style: AppFonts.style(
                    size: 11,
                    color: Colors.grey.shade600,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              localizedTitle,
              style: AppFonts.style(
                size: 14,
                weight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXs),
            Text(
              localizedSummary,
              style: AppFonts.style(
                size: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBanner() {
    // Hide the "Upgrade to Premium" CTA for users who are already premium.
    final auth = Provider.of<AuthProvider>(context);
    if (auth.isPremium) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      decoration: BoxDecoration(
        // Amber→orange premium gradient — gives the CTA a warm, premium feel.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.accentGradientColors,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.softShadow3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Small "PREMIUM" chip — establishes the gold-standard feel.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSm + 2,
                      vertical: AppTheme.spaceXs),
                  margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: L10nText(
                    'premium',
                    style: AppFonts.style(
                        size: 10,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2),
                  ),
                ),
                L10nText(
                  'home_premiumHeadline',
                  style: AppFonts.style(
                    color: Colors.white,
                    size: 18,
                    weight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXs),
                L10nText(
                  'home_premiumSubtitle2',
                  style: AppFonts.style(
                    color: Colors.white.withOpacity(0.92),
                    size: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PremiumScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.accentDarkColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceLg,
                        vertical: AppTheme.spaceSm + 2),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                    ),
                  ),
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: L10nText(
                    'home_premiumCta',
                    style: AppFonts.style(
                        size: 13,
                        weight: FontWeight.w700,
                        color: AppTheme.accentDarkColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.3), width: 1.5),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 32),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 500.ms)
        .slideY(begin: 0.08);
  }

  Widget _buildShimmerGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppTheme.spaceMd,
          crossAxisSpacing: AppTheme.spaceMd,
          childAspectRatio: 0.82,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardColor : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
          );
        },
      ),
    );
  }

  /// Generic error state for a home-screen section. Shows a short message
  /// instead of silently rendering an empty list (which made users think the
  /// section "wasn't clickable" when in fact the stream had errored out).
  Widget _buildSectionError(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spaceXl, horizontal: AppTheme.spaceLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off_rounded,
                size: 18, color: AppTheme.errorColor),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Flexible(
            child: Text(
              message,
              style: AppFonts.style(
                size: 13,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                height: 1.4,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// Generic empty state for a home-screen section. Tappable when [onTap] is
  /// provided so the user can navigate to the full screen even when there's
  /// no preview content (another "not clickable" bug fixed).
  Widget _buildSectionEmpty(String message, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spaceXl, horizontal: AppTheme.spaceLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_outlined,
                size: 18,
                color: AppTheme.primaryColor.withOpacity(0.7)),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Flexible(
            child: Text(
              message,
              style: AppFonts.style(
                size: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                height: 1.4,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: content);
  }

  Widget _buildShimmerList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: SizedBox(
        height: 168,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          itemBuilder: (context, index) {
            return Container(
              width: 220,
              margin: const EdgeInsets.only(right: AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardColor : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
            );
          },
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

/// A simple cycling text widget that auto-rotates through the provided list
/// of announcement titles (no external marquee dependency).
class _MarqueeText extends StatefulWidget {
  final List<String> texts;
  const _MarqueeText({required this.texts});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.texts.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        setState(() {
          _index = (_index + 1) % widget.texts.length;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.texts.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Text(
        widget.texts[_index],
        key: ValueKey(_index),
        style: AppFonts.style(
          size: 12,
          // Theme-aware so the ticker text is readable on both the light
          // ticker card (light mode) and the dark card (dark mode).
          color: isDark ? Colors.grey.shade100 : Colors.grey.shade800,
          weight: FontWeight.w500,
          height: 1.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// =============================================================================
// QUICK ACTION — data holder for the home screen quick-actions grid
// =============================================================================
/// Routes for the 5 quick-action tiles. Using an enum (instead of matching on
/// the label string) keeps routing stable when the label is translated —
/// otherwise switching to Assamese would break the navigation switch.
enum _QuickRoute {
  quiz,
  mock,
  upcoming,
  current,
  bookmarks,
}

/// Immutable descriptor for a single quick-action tile.
class _QuickAction {
  final IconData icon;
  final String labelKey; // l10n key, e.g. 'home_dailyQuiz'
  final Color color; // theme-token color (no raw literals)
  final _QuickRoute route;

  const _QuickAction({
    required this.icon,
    required this.labelKey,
    required this.color,
    required this.route,
  });
}
