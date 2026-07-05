// =============================================================================
// ExamVault - Home Screen
// Shows: Banner carousel + Welcome + Quick actions + Announcements ticker +
// Categories + Popular subjects + Upcoming exams preview + Current affairs +
// Premium banner
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
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
import '../../services/razorpay_service.dart';
import '../../widgets/payment_progress_dialog.dart';
import '../../widgets/payment_success_dialog.dart';
import 'category_detail_screen.dart';
import '../auth/login_screen.dart';
import '../current_affairs/current_affairs_screen.dart';
import '../announcements/announcements_screen.dart';
import '../upcoming_exams/upcoming_exams_screen.dart';
import '../premium/premium_screen.dart';
import '../tests/daily_quiz_screen.dart';
import '../tests/test_series_screen.dart';
import '../tests/test_list_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/bookmarks_screen.dart';
import '../search/search_screen.dart';
import 'all_subjects_screen.dart';
import 'all_categories_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Cached category list for resolving authoritative category IDs in subject cards.
  List<CategoryModel> _categories = [];
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

  @override
  void initState() {
    super.initState();
    _startBannerAutoScroll();
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
      final newSig = cats
          .map((c) => '${c.id}|${c.name}|${c.subjectCount}|${c.icon ?? ""}')
          .join('§');
      if (newSig == _lastCategoriesSig && _categoriesLoaded) {
        // identical payload — skip rebuild to avoid scroll-position jump / flash
        return;
      }
      _lastCategoriesSig = newSig;
      setState(() {
        _categories = cats;
        _categoriesLoaded = true;
      });
    });
  }

  @override
  void dispose() {
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('ExamVault'),
          ],
        ),
        actions: [
          // Global search — opens a full-screen SearchScreen that searches
          // across categories, subjects, tests and current affairs.
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: 'Search',
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
            icon: const Icon(Icons.notifications_outlined),
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
          padding: const EdgeInsets.all(16),
          // RepaintBoundary isolates the scrollable content's layer so that
          // repainting during scroll doesn't bleed into the AppBar / bottom
          // nav. This reduces the visible "flash" the user reported when
          // scrolling to the bottom.
          child: RepaintBoundary(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBannerCarousel(),
              const SizedBox(height: 16),
              _buildGuestBanner(),
              const SizedBox(height: 16),
              _buildWelcomeCard(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildAnnouncementsTicker(),
              const SizedBox(height: 24),
              _buildCategoriesSection(),
              const SizedBox(height: 24),
              _buildPopularSubjects(),
              const SizedBox(height: 24),
              _buildUpcomingExamsPreview(),
              const SizedBox(height: 24),
              _buildCurrentAffairs(),
              const SizedBox(height: 24),
              _buildPremiumBanner(),
              const SizedBox(height: 24),
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
      stream: FirestoreService.getActiveBannersStream(),
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
                      // Banner tap handler. The user reported that taps were
                      // being swallowed by the PageView's horizontal drag
                      // gesture. `behavior: HitTestBehavior.opaque` ensures
                      // taps anywhere on the banner are delivered to this
                      // handler (not just on the non-transparent pixels).
                      if (b.link == null || b.link!.isEmpty) {
                        // No link set — give the user a small toast so they
                        // know the tap registered (otherwise it feels dead).
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('This banner has no link.'),
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
                      // Try external app first; if it fails (no handler),
                      // fall back to in-app browser so the link still opens.
                      try {
                        final launched = await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                        if (!launched) {
                          await launchUrl(uri,
                              mode: LaunchMode.inAppBrowserView);
                        }
                      } catch (_) {
                        // Last-resort fallback.
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
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
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
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.4),
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
                                    const SizedBox(width: 4),
                                    const Text(
                                      'LIVE',
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
                            // Text + CTA
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (b.subtitle != null && b.subtitle!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      b.subtitle!,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (b.linkLabel != null && b.link != null) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        b.linkLabel!,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
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
            const SizedBox(height: 8),
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
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
          ],
        );
      },
    );
  }

  /// Slim banner shown only in guest mode. Reminds the user they're browsing
  /// without an account and gives a one-tap path to sign in. Tapping it opens
  /// the login screen; after login the user returns to the app with full
  /// access to whatever they've purchased.
  Widget _buildGuestBanner() {
    final auth = Provider.of<AuthProvider>(context);
    if (!auth.isGuest) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, size: 20, color: AppTheme.accentColor),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Browsing as guest. Sign in to unlock premium tests & save progress.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
            child: const Text('Sign In',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final auth = Provider.of<AuthProvider>(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.user?.name ?? 'Student',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    auth.isPremium ? 'Premium Member' : 'Free Member',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.waving_hand, color: Colors.yellow, size: 40),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.quiz, 'label': 'Daily Quiz', 'color': const Color(0xFFFF6F00)},
      {'icon': Icons.assignment, 'label': 'Mock Tests', 'color': const Color(0xFF1565C0)},
      {'icon': Icons.event_available, 'label': 'Upcoming', 'color': const Color(0xFF43A047)},
      {'icon': Icons.newspaper, 'label': 'Current Affairs', 'color': const Color(0xFF8E24AA)},
      {'icon': Icons.bookmark, 'label': 'Bookmarks', 'color': const Color(0xFFE65100)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return GestureDetector(
          onTap: () {
            final label = action['label'] as String;
            if (label == 'Daily Quiz') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyQuizScreen()));
            } else if (label == 'Mock Tests') {
              // Open the Test Series screen so users can browse ALL test
              // types (Mock, Previous Year, Daily Quiz, Practice, Subject-wise)
              // — not just upcoming exams. Previously the home screen had no
              // direct entry to mock tests, so users only saw upcoming exams
              // and previous-year papers in the app.
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TestSeriesScreen()));
            } else if (label == 'Current Affairs') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CurrentAffairsScreen()));
            } else if (label == 'Upcoming') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UpcomingExamsScreen()));
            } else if (label == 'Bookmarks') {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarksScreen()));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (action['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    action['icon'] as IconData,
                    color: action['color'] as Color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  action['label'] as String,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== ANNOUNCEMENTS TICKER ====================
  Widget _buildAnnouncementsTicker() {
    return StreamBuilder<List<AnnouncementModel>>(
      stream: FirestoreService.getAnnouncementsStream(limit: 5),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final list = snapshot.data!;
        return GestureDetector(
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AnnouncementsScreen()));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                // LIVE pulsing badge — the "live" indicator the user saw in
                // the admin preview but was missing in the user app.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
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
                      const SizedBox(width: 3),
                      const Text(
                        'LIVE',
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Updates',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MarqueeText(
                    texts: list.map((a) => a.title).toList(),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.primaryColor, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Exam Categories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
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
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // _categories is kept fresh by _categoriesSub in initState.
        // No StreamBuilder here — having both a subscription AND a StreamBuilder
        // created two Firestore listeners and caused every update to rebuild
        // the widget twice.
        if (!_categoriesLoaded)
          _buildShimmerGrid()
        else if (_categories.isEmpty)
          _buildSectionEmpty('No categories available')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              return _buildCategoryCard(_categories[index]);
            },
          ),
      ],
    );
  }

  Widget _buildCategoryCard(CategoryModel category) {
    final color = AppTheme.categoryColors[category.name] ?? AppTheme.primaryColor;
    // Use Selector so only the lock state (a single bool) is watched from
    // AuthProvider. Without this, EVERY notifyListeners() call (including
    // unrelated auth events) would rebuild every category card in the grid,
    // making the app noticeably slow after a premium purchase.
    return Selector<AuthProvider, bool>(
      selector: (_, auth) =>
          category.isPremium && !auth.hasCategoryAccess(category.id),
      builder: (context, categoryLocked, _) {
        return GestureDetector(
          onTap: () {
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Center(
                        child: Text(
                          category.icon ?? '📚',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${category.subjectCount} Subjects',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    // Premium price hint under the subject count for locked cats.
                    if (categoryLocked && category.premiumPrice > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '₹${category.premiumPrice}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Crown badge for premium categories (top-right corner).
              if (category.isPremium)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: categoryLocked
                          ? AppTheme.accentColor
                          : AppTheme.accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      categoryLocked ? Icons.lock : Icons.workspace_premium,
                      size: 12,
                      color: categoryLocked ? Colors.white : AppTheme.accentColor,
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
                    ? 'Sign in to unlock "${category.name}" and all its tests.'
                    : canBuyExamPack
                        ? 'Unlock "${category.name}" and all its tests for ₹${category.premiumPrice}, or upgrade to Premium for unlimited access.'
                        : 'Subscribe to Premium to unlock "${category.name}" and all its tests.',
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
          itemName: category.name,
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
            const Text(
              'Popular Subjects',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<SubjectModel>>(
          stream: FirestoreService.getSubjectsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerList();
            }
            // Surface stream errors instead of silently showing "No subjects
            // available". This is the same root cause as the category detail
            // screen — if the subjects stream errors out, the user sees an
            // empty section and thinks "Start Now is not clickable".
            if (snapshot.hasError) {
              return _buildSectionError('Couldn\'t load subjects');
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildSectionEmpty('No subjects available yet');
            }
            return SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final subject = snapshot.data![index];
                  return _buildSubjectCard(subject);
                },
              ),
            );
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
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
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subject.icon ?? '📚',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${subject.testCount} Tests',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subject.description ?? '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            // "Start Now" CTA — the whole card is tappable, this is a visual
            // affordance. Fixed-width container so the text never truncates.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Start Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 14),
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
            const Text(
              'Upcoming Exams',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const UpcomingExamsScreen()));
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<UpcomingExamModel>>(
          stream: FirestoreService.getUpcomingExamsStream(limit: 3),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerList();
            }
            if (snapshot.hasError) {
              return _buildSectionError('Couldn\'t load upcoming exams');
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildSectionEmpty(
                'No upcoming exams scheduled',
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UpcomingExamsScreen()));
                },
              );
            }
            return Column(
              children: snapshot.data!.map((e) => _buildUpcomingExamMiniCard(e)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUpcomingExamMiniCard(UpcomingExamModel e) {
    final days = e.daysRemaining;
    final isPast = days < 0;
    // User reported: tapping a mini exam card on the Home screen opens a
    // single exam directly instead of the full "Upcoming Exams" list. The
    // handler below ALWAYS opens the full UpcomingExamsScreen (View All),
    // never a specific exam detail. Using Material+InkWell so the tap has a
    // visible ripple — the user can SEE the tap registered before the
    // navigation transition fires.
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const UpcomingExamsScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: isPast
                      ? Colors.grey
                      : days <= 30
                          ? Colors.red
                          : AppTheme.primaryColor,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${e.examDate.day}/${e.examDate.month}/${e.examDate.year}'
                        '${e.organization != null && e.organization!.isNotEmpty ? ' • ${e.organization}' : ''}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPast
                        ? Colors.grey.shade200
                        : days <= 30
                            ? Colors.red.withOpacity(0.1)
                            : AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPast ? '${-days}d ago' : '$days days',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isPast
                          ? Colors.grey
                          : days <= 30
                              ? Colors.red
                              : AppTheme.primaryColor,
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
            const Text(
              'Current Affairs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CurrentAffairsScreen()),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<CurrentAffairModel>>(
          stream: FirestoreService.getCurrentAffairsStream(limit: 3),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerList();
            }
            if (snapshot.hasError) {
              return _buildSectionError('Couldn\'t load current affairs');
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildSectionEmpty(
                'No current affairs available',
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CurrentAffairsScreen()));
                },
              );
            }
            return Column(
              children: snapshot.data!.map((affair) {
                return _buildCurrentAffairCard(affair);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCurrentAffairCard(CurrentAffairModel affair) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CurrentAffairsScreen()));
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: affair.isImportant ? AppTheme.accentColor : AppTheme.primaryColor,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${affair.date.day} ${_monthName(affair.date.month)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (affair.isImportant) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Important',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                affair.category,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            affair.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            affair.summary,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.accentGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unlock ExamVault Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Get unlimited tests, detailed solutions & more',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PremiumScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.accentColor,
                  ),
                  child: const Text('Upgrade Now'),
                ),
              ],
            ),
          ),
          const Icon(Icons.workspace_premium, color: Colors.white, size: 60),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SizedBox(
        height: 140,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          itemBuilder: (context, index) {
            return Container(
              width: 200,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
        style: TextStyle(
          fontSize: 12,
          // Theme-aware so the ticker text is readable on both the light
          // blue-ish ticker card (light mode) and the dark blue-ish card
          // (dark mode). Previously hardcoded to grey.shade800 which was
          // near-invisible in dark mode.
          color: isDark ? Colors.grey.shade100 : Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
