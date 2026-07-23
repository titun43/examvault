// =============================================================================
// ExamVault - Test List Screen (Tests in a subject OR Test details)
// Shows the test's price (if set by admin) and a Buy/Start button based on
// the user's access: premium users and already-purchased tests → Start;
// paid unpurchased tests → Buy ₹X (Razorpay per-test purchase).
//
// v1.28+ — FAST PAYMENT UX. The Buy flow now shows loading indicators during
// the two network steps that were previously invisible to the user:
//   1. "Preparing payment..." while createOrder runs (backend → Razorpay API)
//   2. "Verifying payment..." while verifyPayment runs (signature check + grant)
// After a successful purchase, a positive AccessDecision is written directly
// to the cache (markTestPurchased) instead of clearing it — so the next access
// check is instant (no network round-trip). The _startTest flow also has a
// local fast-path: if the local user model says the user has access (premium
// or purchased), navigate directly to TakeTestScreen without a server round-
// trip; TakeTestScreen does its own server check as the final gatekeeper.
//
// v1.27+ — SERVER-SIDE PREMIUM CHECK. The button label now reflects the
// server's view of the user's premium status (not the potentially-stale
// Firestore copy). On screen load we call AccessService.checkPremiumOnly()
// which hits /api/payments/access-check?type=all. The result is cached for
// 60s by AccessService, so scrolling / re-opening doesn't re-hit the API.
//
// v1.23+ — server-side access check. Before starting a PAID test, the app
// calls AccessService.checkTestAccess(). If the backend denies access, a
// purchase sheet is shown: Buy this test / Go Premium. FREE tests open
// immediately without a server round-trip.
//
// =============================================================================
// v3 SINGLE-COLUMN REDESIGN (visual layer only — payment/access logic unchanged):
//   - Test cards switched from a 2-column SliverGrid back to a single-column
//     SliverList (one full-width card per row). Better readability, more
//     Testbook-like, no more cramped square tiles.
//   - Each card is now a HORIZONTAL layout:
//       * Top: 56×56 category-tinted icon tile + title (2 lines, 15 px w700,
//         Hero) + corner badge (FREE / PREMIUM / ₹X) on the right.
//       * Subtitle line: type · year (category-colored, 12 px w600).
//       * Optional "Completed · N%" green line if the user has a prior result.
//       * Thin divider.
//       * Bottom row: inline meta chips (Q count · duration · negative marking)
//         on the left, compact CTA button (Start / Unlock Premium / Buy ₹X) on
//         the right. Button height 36 to align with the chips.
//   - Shimmer skeleton updated to match the new horizontal single-column shape.
//   - New helpers: _metaChip (icon+label inline), _buildCompactActionButton
//     (three variants matching the access logic, height 36). _GradientButton
//     gains a `compact` flag (height 36, smaller icon/font/padding).
// =============================================================================
// v2 MODERNIZATION (visual layer only — payment/access logic unchanged):
//   - Plain AppBar replaced with a category-themed SliverAppBar hero header.
//     The hero shows the subject icon + name + "N Tests" count + an optional
//     category chip, all wrapped in AppTheme.gradientFor(categoryId) so every
//     exam keeps its signature look (ADRE → orange, APSC → violet, TET → pink,
//     etc.). Falls back to the brand emerald gradient when no category match.
//   - Loading state now renders a 4-card shimmer skeleton list (using the
//     `shimmer` package) inside visible white/dark cards — no more bare
//     CircularProgressIndicator.
//   - Empty state is illustrated: large 📝 in a soft primaryColor circle,
//     bilingual title (test_noTests), subtitle (test_noTestsDesc), and a
//     primary-colored CTA line (test_checkBackSoon). A separate filtered
//     empty state (test_noMatchingTests) appears when a chip yields no rows.
//   - Added a horizontal filter-chip row (All / Free / Premium / Mock /
//     Previous Year) with bilingual labels. Active chip = filled with
//     AppTheme.primaryColor; inactive = outlined. Staggered flutter_animate
//     entrance (index * 60 ms).
//   - Test cards completely redesigned:
//       * Colored left accent bar (4 px) using AppTheme.colorFor(category).
//       * Icon tile (40×40) with the test-type emoji on a category-tinted bg.
//       * Bold bilingual title (16 px / w700) with Assamese font fallback.
//       * Badges with VISUAL HIERARCHY:
//           - FREE  → green pill (AppTheme.successColor, filled)
//           - Premium-only → amber gradient pill (AppTheme.accentGradientColors)
//           - Paid (₹X) → amber solid pill (AppTheme.accentColor)
//           - Test type (Mock / Previous Year) → outlined primary pill
//           - Year → outlined primary pill
//         No more flat Wrap of identically-styled pills.
//       * Meta row with ⏱ duration / 📝 questions / 🎯 marks / 📈 attempts
//         using small leading icons.
//       * Negative-marking warning chip (⚠ + test_negativeMarking) in
//         AppTheme.warningColor when test.negativeMarking is true.
//       * Action button with three visual states:
//           - Start Test → filled AppTheme.primaryColor
//           - Unlock with Premium → outlined amber
//           - Buy Now ₹X → amber gradient (custom _GradientButton)
//       * Soft shadow (AppTheme.softShadow1), radiusLg corners, subtle border,
//         dark-mode aware (AppTheme.darkCardColor vs Colors.white).
//       * Entrance animation: fadeIn + slideY with index * 60 ms stagger.
//   - Subject-pack banner modernized: primary gradient card, icon tile,
//     bilingual title/subtitle (test_unlockSubject / test_unlockSubjectDesc),
//     white pill CTA with the price. Soft shadow + radiusLg.
//   - Purchase bottom sheet modernized: dark-aware surface, design-token
//     spacing/radii, bilingual title/subtitle/option labels, AppFonts text
//     styles. Sheet logic (Buy / Go Premium / dismiss) is UNCHANGED.
//   - Payment progress + success dialog text now flows through tr() so the
//     "Preparing payment…" / "Verifying payment…" / "Open Test" / "Payment
//     failed: …" strings respect the user's language preference. The
//     Razorpay call structure, callbacks, progress dialog API, and success
//     dialog API are UNCHANGED.
//   - Every user-visible string now uses tr(context, 'key') or L10nText.
//     New l10n keys added to app_strings.dart (english + assamese maps):
//     test_noMatchingTests, test_noMatchingTestsDesc, test_clearFilter,
//     test_unableToLoad, test_unableToLoadDesc, test_unlockSubject,
//     test_unlockSubjectDesc, test_unlockTest, test_buyOrPremiumDesc,
//     test_premiumOnlyDesc, test_buyThisTest, test_attemptAnytime,
//     test_unlimitedAccess, test_maybeLater, test_paymentTakingLong,
//     test_preparingPayment, test_verifyingPayment, test_paymentFailedPrefix,
//     test_paymentFailedGeneric, test_openTest, test_signInToPurchase,
//     test_subjectPackPrefix, test_premiumOnlyHint, test_paidHint.
//   - All hardcoded spacing/radii/shadows replaced with AppTheme tokens
//     (spaceXs/Sm/Md/Lg/Xl/Xxl, radiusSm/Md/Lg/Xl/Full, softShadow1/2).
//   - NO blue/indigo colors anywhere — primaryColor (emerald) or category
//     colors only. The legacy file had zero blue literals too, so this is a
//     preservation guarantee rather than a removal.
//   - Payment / access / Razorpay / exam-pack / subject-pack logic is
//     preserved EXACTLY: _startTest, _showPurchaseSheet (flow), _purchaseTest,
//     _purchaseSubjectPack, AccessService calls, markTestPurchased /
//     markSubjectPackPurchased cache writes, the fast-path local user model
//     check, the server-side premium check on load, the local exam-pack
//     pre-seed, the SharedPreferences cache pre-seed, the constructor
//     signature, and all navigation to TakeTestScreen / LoginScreen /
//     /premium / /my-purchases.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../l10n/app_localizations.dart';
import '../../models/subject_model.dart';
import '../../models/test_model.dart';
import '../../models/test_result_model.dart';
import '../../models/user_model.dart';
import '../../services/access_service.dart';
import '../../services/exam_pack_cache_service.dart';
import '../../services/firestore_service.dart';
import '../../services/payment_api_service.dart';
import '../../services/razorpay_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../utils/localized_content.dart';
import '../../widgets/payment_progress_dialog.dart';
import '../../widgets/payment_success_dialog.dart';
import 'test_instructions_screen.dart';
import '../auth/login_screen.dart';

class TestListScreen extends StatefulWidget {
  final SubjectModel? subject;
  final String? testId;
  /// Authoritative categoryId (the Firestore category document id) — when the
  /// user navigated here from CategoryDetailScreen, this is `category.id`.
  /// We MUST use this for the server-side access check (not `subject.categoryId`)
  /// because `getSubjectsStream` falls back to matching by category NAME or
  /// SLUG, so `subject.categoryId` can hold the name/slug instead of the real
  /// id. `ExamPackPurchase.categoryId` (created during payment) always stores
  /// the real Firestore category id, so without this authoritative value the
  /// exam-pack tier of the access check silently fails and a user who already
  /// bought the exam pack sees a premium lock on every test inside it.
  final String? categoryId;

  const TestListScreen({
    super.key,
    this.subject,
    this.testId,
    this.categoryId,
  });

  @override
  State<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends State<TestListScreen> {
  // Server-side premium status. null = not checked yet (fall back to local).
  // true/false = server confirmed the user is/isn't premium.
  // This is refreshed every time the screen loads (AccessService caches it
  // for 60s, so rapid re-opens don't re-hit the API).
  bool? _serverIsPremium;
  bool _premiumChecking = true;

  // Server-side exam-pack access for this category. If the user bought the
  // category exam pack, ALL tests inside it are unlocked — no per-test
  // purchase needed. We resolve this once on screen load (cached 60s) and
  // use it to correctly set `hasAccess` in _buildTestCard. Without this,
  // exam-pack buyers see a "Buy" button on every test even after paying.
  bool _serverHasExamPackAccess = false;

  // Server-side subject-pack access for this subject. If the user bought the
  // subject pack, ALL tests inside this subject are unlocked. Resolved once on
  // screen load (cached 60s by AccessService). Also drives the visibility of
  // the "Unlock this subject for ₹X" banner — hidden when true.
  bool _serverHasSubjectPackAccess = false;

  // v2: active filter chip. Defaults to "all" so the full list shows. Tapping
  // a chip calls setState and the build filters the streamed tests locally.
  _TestFilter _activeFilter = _TestFilter.all;

  // testId -> user's LATEST attempt for that test (by attemptedAt). Powers
  // the "Completed · X%" badge on each card so a user browsing a category
  // with many tests can see at a glance which ones they've already taken.
  Map<String, TestResultModel> _latestResults = {};

  @override
  void initState() {
    super.initState();
    // INSTANT LOCAL PRE-SEED (synchronous) — before the first frame builds,
    // check the Firestore-loaded purchasedCategoryIds for this category. If
    // the user already bought this exam pack, _serverHasExamPackAccess flips
    // to true NOW — no "Buy" flash while the server access-check runs.
    // This is the key fix for the exam-pack flash: the UI renders correctly
    // on the VERY FIRST frame, not after a 300-900ms network round-trip.
    _seedLocalExamPackAccess();
    // ASYNC CACHE PRE-SEED (fast, ~10ms) — also check the persistent
    // SharedPreferences exam-pack cache. This catches the edge case where
    // Firestore read failed on launch (fallback UserModel has empty
    // purchasedCategoryIds) but the cache still has the purchase from a
    // previous session. Fire-and-forget; setState when it returns.
    _seedCachedExamPackAccess();
    _refreshAccessStatus();
    // Fetch server-side subject-pack access for this subject (if the admin
    // set a premiumPrice > 0). The result hides the "Unlock this subject"
    // banner and grants access to all tests in this subject.
    if (widget.subject != null && widget.subject!.premiumPrice > 0) {
      _fetchSubjectPackStatus(widget.subject!.id);
    }
    _loadLatestResults();
  }

  Future<void> _loadLatestResults() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;
    try {
      final results = await FirestoreService.getLatestResultsByTestId(user.id);
      if (!mounted) return;
      setState(() => _latestResults = results);
    } catch (_) {
      // Non-fatal — badge just won't show if this fails.
    }
  }

  /// Synchronous local pre-seed for exam-pack access. Reads the
  /// Firestore-loaded `purchasedCategoryIds` from the in-memory UserModel
  /// and sets `_serverHasExamPackAccess = true` if this category is in the
  /// list. Runs in initState BEFORE the first build → no flash.
  void _seedLocalExamPackAccess() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;
    final rawCategoryId =
        (widget.categoryId != null && widget.categoryId!.isNotEmpty)
            ? widget.categoryId!
            : (widget.subject?.categoryId ?? '');
    if (rawCategoryId.isEmpty) return;
    if (user.purchasedCategoryIds.contains(rawCategoryId)) {
      _serverHasExamPackAccess = true;
    }
  }

  /// Async pre-seed from the persistent SharedPreferences exam-pack cache.
  /// Fast (~10ms) but still async, so it runs as fire-and-forget in initState.
  /// If the cache says the user has this category, flips
  /// `_serverHasExamPackAccess = true` and setState. This complements the
  /// synchronous `_seedLocalExamPackAccess` for the edge case where the
  /// Firestore UserModel is missing the purchase (e.g. Firestore read failed
  /// on launch) but the cache still has it.
  Future<void> _seedCachedExamPackAccess() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) return;
    final rawCategoryId =
        (widget.categoryId != null && widget.categoryId!.isNotEmpty)
            ? widget.categoryId!
            : (widget.subject?.categoryId ?? '');
    if (rawCategoryId.isEmpty) return;
    if (_serverHasExamPackAccess) return; // already seeded synchronously
    final cached = await ExamPackCacheService.hasCategoryAccess(
      userId: user.id,
      categoryId: rawCategoryId,
    );
    if (cached && mounted && !_serverHasExamPackAccess) {
      setState(() => _serverHasExamPackAccess = true);
    }
  }

  /// Fetch server-side premium + exam-pack access in parallel. Both results
  /// are cached by AccessService for 60 s, so re-opens are instant.
  ///
  /// PERFORMANCE (v1.30+): We set _premiumChecking=false immediately using the
  /// local UserModel so the list renders instantly without a loading spinner.
  /// The server check then runs in the background and updates _serverIsPremium
  /// if the result differs from local state. This means:
  ///   • FREE users: list renders instantly (local says non-premium → buttons
  ///     show correctly). Server check runs and no-op for free users.
  ///   • PREMIUM users: list renders instantly (local says premium → "Start"
  ///     buttons). Server check confirms/corrects in background.
  ///   • GUEST users: skip server entirely — guests can never be premium.
  ///
  /// Edge case: if the user is premium on the server but local model is stale
  /// (e.g. bought on another device), _fetchPremiumStatus will update
  /// _serverIsPremium=true after returning, and the UI re-renders with the
  /// correct (unlocked) button labels. There may be a brief flash of "Buy"
  /// buttons, but the content is accessible within one network round-trip.
  Future<void> _refreshAccessStatus() async {
    final rawCategoryId = (widget.categoryId != null && widget.categoryId!.isNotEmpty)
        ? widget.categoryId!
        : (widget.subject?.categoryId ?? '');

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    // GUEST: no premium possible. Skip server call entirely.
    if (auth.isGuest) {
      if (mounted) {
        setState(() {
          _serverIsPremium = false;
          _premiumChecking = false;
        });
      }
      return;
    }

    // FAST PATH — locally-confirmed premium user.
    // Premium subscription covers ALL content in ALL categories — no server
    // call needed. Skipping the 3 background calls (_fetchPremiumStatus +
    // resolveCategoryId + _fetchExamPackStatus) eliminates the 300-900ms
    // network overhead premium users were experiencing on every test list open.
    // The local model is set by markPremium() on purchase and backed by the
    // USER-SPECIFIC SharedPreferences cache (isPremium_${userId}), so it is
    // reliable across restarts — no "Locked" flash while the backend sync runs.
    if (user?.isPremium == true) {
      if (mounted) {
        setState(() {
          _serverIsPremium = true;
          _premiumChecking = false;
        });
      }
      return;
    }

    // INSTANT RENDER: Set _premiumChecking=false immediately using local state
    // so the list renders without a spinner. The server check below will update
    // _serverIsPremium if the result differs from local. Doing this eliminates
    // the 300-800ms loading delay free users experienced on every screen open.
    if (mounted) {
      setState(() {
        // Use local isPremium as the initial value; server check will correct
        // if stale. Using null here would keep premiumChecking=true (old bug).
        _serverIsPremium = user?.isPremium ?? false;
        _premiumChecking = false;
      });
    }

    // Resolve slug/name → real Firestore document id IN PARALLEL with the
    // premium check. The subject's `categoryId` field can hold a name or slug
    // (the admin may have typed it that way). Without resolution, the backend's
    // exam-pack access tier silently fails because ExamPackPurchase stores the
    // real document id (not the slug) — so a paid user sees "Go Premium".
    String resolvedCategoryId = rawCategoryId;
    await Future.wait(<Future>[
      _fetchPremiumStatus(),
      if (rawCategoryId.isNotEmpty)
        FirestoreService.resolveCategoryId(rawCategoryId).then((r) {
          if (r != null && r.isNotEmpty) resolvedCategoryId = r;
        }),
    ]);

    if (resolvedCategoryId.isNotEmpty) {
      await _fetchExamPackStatus(resolvedCategoryId);
    }
  }


  Future<void> _fetchPremiumStatus() async {
    try {
      final decision = await AccessService.checkPremiumOnly();
      if (!mounted) return;
      setState(() {
        _serverIsPremium = decision.allowed;
        _premiumChecking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverIsPremium = null;
        _premiumChecking = false;
      });
    }
  }

  Future<void> _fetchExamPackStatus(String categoryId) async {
    try {
      final decision = await AccessService.checkCategoryAccess(categoryId);
      if (!mounted) return;
      // Set the flag to the SERVER'S decision — true if allowed, false if
      // denied. Setting false on denial is important now that we pre-seed
      // from local sources: if a refund/expiry revoked the exam pack, the
      // server denial must overwrite the optimistic local true. (The actual
      // test-open gate in TakeTestScreen does its own server check as the
      // final gatekeeper, so a brief true→false flip here is safe.)
      setState(() => _serverHasExamPackAccess = decision.allowed);
    } catch (_) {
      // Silently ignore — the server-side per-test access check in
      // _startTest will still catch exam-pack ownership correctly. Leave
      // the locally-seeded value as-is (optimistic).
    }
  }

  /// Fetches server-side subject-pack access. If the user already bought this
  /// subject pack, `_serverHasSubjectPackAccess` flips to true → all tests in
  /// this subject show "Start" and the "Unlock this subject" banner hides.
  Future<void> _fetchSubjectPackStatus(String subjectId) async {
    try {
      final decision = await AccessService.checkSubjectAccess(subjectId);
      if (!mounted) return;
      setState(() => _serverHasSubjectPackAccess = decision.allowed);
    } catch (_) {
      // Silently ignore — the per-test access check in TakeTestScreen is the
      // final gatekeeper.
    }
  }

  /// Effective premium status: server-side if available, else local fallback.
  bool _effectiveIsPremium(UserModel? user) {
    if (_serverIsPremium != null) return _serverIsPremium!;
    return user?.isPremium ?? false;
  }

  /// v2: locally filter the streamed tests by the active filter chip. Cheap
  /// (in-memory List.where) — runs on every build. Returns a NEW list so the
  /// caller can safely read its length.
  List<TestModel> _applyFilter(List<TestModel> tests) {
    switch (_activeFilter) {
      case _TestFilter.all:
        return tests;
      case _TestFilter.free:
        return tests.where((t) => !t.isPaid).toList();
      case _TestFilter.premium:
        return tests.where((t) => t.isPremium).toList();
      case _TestFilter.mock:
        return tests.where((t) => t.type == TestType.mock).toList();
      case _TestFilter.previousYear:
        return tests.where((t) => t.type == TestType.previousYear).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subject = widget.subject;
    // Best-effort category-name resolution: subject.categoryId may hold the
    // category name, slug, or Firestore id (admin entry varies). Pass it to
    // gradientFor/colorFor — they do case-insensitive `.contains()` matching
    // against the known category keys, so "ADRE", "adre", and "adre-3-2024"
    // all resolve to the ADRE palette. Unknown ids fall back to brand emerald.
    final categoryName = subject?.categoryId;
    final heroGradient = AppTheme.gradientFor(categoryName);
    final heroTitle = subject != null
        ? lc(context, subject.name, subject.nameAs)
        : tr(context, 'subject_tests');
    final heroIcon = subject?.icon ?? '📝';

    // Subject-pack banner visibility — same condition as v1, computed up
    // front so the StreamBuilder's sliver list can conditionally include it.
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    final isPremiumUser = _effectiveIsPremium(user);
    final showSubjectPackBanner = subject != null &&
        subject.premiumPrice > 0 &&
        !_serverHasSubjectPackAccess &&
        !isPremiumUser;

    return Scaffold(
      body: StreamBuilder<List<TestModel>>(
        stream: FirestoreService.getTestsStream(
          subjectId: subject?.id,
          isPublished: true,
        ),
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData;
          final hasError = snapshot.hasError;
          final allTests = snapshot.data ?? const <TestModel>[];
          final tests = _applyFilter(allTests);
          final hasDataButFilterEmpty =
              allTests.isNotEmpty && tests.isEmpty;

          return CustomScrollView(
            slivers: [
              // ==================== HERO HEADER ====================
              _buildHero(
                context: context,
                title: heroTitle,
                icon: heroIcon,
                categoryName: categoryName,
                gradient: heroGradient,
                testCount: allTests.length,
                subjectHeroTag: subject != null && subject.id.isNotEmpty
                    ? 'subject-icon-${subject.id}'
                    : null,
              ),

              // ==================== SUBJECT-PACK BANNER ====================
              if (showSubjectPackBanner)
                SliverToBoxAdapter(
                  child: _buildSubjectPackBanner(context, subject!),
                ),

              // ==================== CONTENT STATES ====================
              if (isLoading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceLg,
                    AppTheme.spaceSm,
                    AppTheme.spaceLg,
                    AppTheme.spaceXl,
                  ),
                  sliver: _buildShimmerList(isDark),
                )
              else if (hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(context),
                )
              else if (allTests.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context, isFiltered: false),
                )
              else if (hasDataButFilterEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context, isFiltered: true),
                )
              else ...[
                // Filter chips row (sticky-ish: scrolls with content).
                SliverToBoxAdapter(child: _buildFilterChips(context, isDark)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceLg,
                    AppTheme.spaceSm,
                    AppTheme.spaceLg,
                    AppTheme.spaceXl,
                  ),
                  sliver: SliverList(
                    // Single-column professional list (Testbook-style):
                    // one full-width card per row. Horizontal layout inside
                    // each card — icon tile + title/badge on top, meta + CTA
                    // button on the bottom — gives the user a clean, scannable
                    // vertical stream that reads well on every screen size.
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: EdgeInsets.only(
                          bottom: index == tests.length - 1
                              ? 0
                              : AppTheme.spaceMd,
                        ),
                        child: _buildTestCard(
                            context, tests[index], index, isDark),
                      ),
                      childCount: tests.length,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // HERO HEADER
  // ===========================================================================
  Widget _buildHero({
    required BuildContext context,
    required String title,
    required String icon,
    required String? categoryName,
    required List<Color> gradient,
    required int testCount,
    String? subjectHeroTag,
  }) {
    // Show the category chip ONLY when categoryId exactly matches a known
    // category key — otherwise we'd be showing a slug or Firestore id.
    final String knownCategory = (categoryName != null && categoryName.isNotEmpty)
        ? AppTheme.categoryColors.keys.firstWhere(
            (k) => k.toLowerCase() == categoryName.toLowerCase(),
            orElse: () => '',
          )
        : '';

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: gradient.first,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceLg,
                AppTheme.spaceXl,
                AppTheme.spaceLg,
                AppTheme.spaceLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (knownCategory.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSm + 4,
                        vertical: AppTheme.spaceXs + 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        knownCategory.toUpperCase(),
                        style: AppFonts.style(
                          size: 10,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: -0.15),
                    const SizedBox(height: AppTheme.spaceSm),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Subject icon — wrapped in Hero (when a subject is
                      // present) so it receives the flying icon from the
                      // subject_detail / category_detail screen.
                      subjectHeroTag != null
                          ? Hero(
                              tag: subjectHeroTag,
                              child: _subjectIconTile(icon),
                            )
                          : _subjectIconTile(icon),
                      const SizedBox(width: AppTheme.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: AppFonts.style(
                                size: 22,
                                weight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$testCount ${tr(context, 'subject_tests')}',
                              style: AppFonts.style(
                                size: 12,
                                weight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.92),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 450.ms)
                      .slideY(begin: 0.12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the subject-icon tile used in the hero header. Extracted so it
  /// can be shared between the plain (no-Hero) and Hero-wrapped variants.
  Widget _subjectIconTile(String icon) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: Colors.white.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(icon, style: const TextStyle(fontSize: 28)),
      ),
    );
  }

  // ===========================================================================
  // SHIMMER LOADING SKELETON
  // ===========================================================================
  Widget _buildShimmerList(bool isDark) {
    final cardColor = isDark ? AppTheme.darkCardColor : Colors.white;
    final baseColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.grey.shade300;
    final highlightColor = isDark
        ? Colors.white.withOpacity(0.14)
        : Colors.grey.shade100;

    // Single-column shimmer matching the real SliverList (one full-width
    // horizontal card per row). 6 rows fills the viewport on most phones
    // and gives a smooth scroll-feel during the brief fetch window.
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: EdgeInsets.only(
            bottom: index == 5 ? 0 : AppTheme.spaceMd,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: AppTheme.softShadow1,
            ),
            child: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: icon tile (56×56) + title block + badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _skeletonBox(56, 56, AppTheme.radiusMd),
                      const SizedBox(width: AppTheme.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _skeletonBox(
                                          double.infinity, 14, AppTheme.radiusSm),
                                      const SizedBox(height: 6),
                                      _skeletonBox(
                                          120, 14, AppTheme.radiusSm),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spaceSm),
                                _skeletonBox(
                                    44, 20, AppTheme.radiusFull),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _skeletonBox(70, 10, AppTheme.radiusSm),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  // Divider
                  _skeletonBox(double.infinity, 1, AppTheme.radiusFull),
                  const SizedBox(height: AppTheme.spaceSm),
                  // Bottom row: meta chips + button
                  Row(
                    children: [
                      _skeletonBox(50, 12, AppTheme.radiusSm),
                      const SizedBox(width: AppTheme.spaceMd),
                      _skeletonBox(50, 12, AppTheme.radiusSm),
                      const Spacer(),
                      _skeletonBox(90, 36, AppTheme.radiusMd),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        childCount: 6,
      ),
    );
  }

  Widget _skeletonBox(double width, double height, double radius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey, // any opaque color — Shimmer's ShaderMask recolors it
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE (illustrated)
  // ===========================================================================
  Widget _buildEmptyState(BuildContext context, {required bool isFiltered}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDark ? Colors.white : const Color(0xFF1C1917);
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceXxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('📝', style: TextStyle(fontSize: 44)),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1),
          const SizedBox(height: AppTheme.spaceXl),
          L10nText(
            isFiltered ? 'test_noMatchingTests' : 'test_noTests',
            style: AppFonts.style(
              size: 18,
              weight: FontWeight.w700,
              color: titleColor,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 120.ms, duration: 400.ms),
          const SizedBox(height: AppTheme.spaceSm),
          L10nText(
            isFiltered ? 'test_noMatchingTestsDesc' : 'test_noTestsDesc',
            style: AppFonts.style(
              size: 13,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 220.ms, duration: 400.ms),
          const SizedBox(height: AppTheme.spaceXs),
          if (isFiltered)
            TextButton(
              onPressed: () => setState(() => _activeFilter = _TestFilter.all),
              child: L10nText(
                'test_clearFilter',
                style: AppFonts.style(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
            ).animate().fadeIn(delay: 320.ms, duration: 400.ms)
          else
            L10nText(
              'test_checkBackSoon',
              style: AppFonts.style(
                size: 12,
                weight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
            ).animate().fadeIn(delay: 320.ms, duration: 400.ms),
        ],
      ),
    );
  }

  // ===========================================================================
  // ERROR STATE
  // ===========================================================================
  Widget _buildErrorState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1917);
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceXxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppTheme.errorColor,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: AppTheme.spaceXl),
          L10nText(
            'test_unableToLoad',
            style: AppFonts.style(
              size: 18,
              weight: FontWeight.w700,
              color: titleColor,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 120.ms, duration: 400.ms),
          const SizedBox(height: AppTheme.spaceSm),
          L10nText(
            'test_unableToLoadDesc',
            style: AppFonts.style(
              size: 13,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 220.ms, duration: 400.ms),
        ],
      ),
    );
  }

  // ===========================================================================
  // FILTER CHIPS
  // ===========================================================================
  Widget _buildFilterChips(BuildContext context, bool isDark) {
    final chips = const <_FilterChipData>[
      _FilterChipData(key: 'test_all', filter: _TestFilter.all),
      _FilterChipData(key: 'test_free', filter: _TestFilter.free),
      _FilterChipData(key: 'test_premium', filter: _TestFilter.premium),
      _FilterChipData(key: 'test_mock', filter: _TestFilter.mock),
      _FilterChipData(key: 'test_previousYear', filter: _TestFilter.previousYear),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceLg,
        AppTheme.spaceMd,
        AppTheme.spaceLg,
        AppTheme.spaceSm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < chips.length; i++) ...[
              _buildFilterChip(context, chips[i], isDark)
                  .animate()
                  .fadeIn(delay: (i * 60).ms, duration: 350.ms)
                  .slideX(begin: 0.08),
              if (i < chips.length - 1)
                const SizedBox(width: AppTheme.spaceSm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    _FilterChipData data,
    bool isDark,
  ) {
    final isActive = _activeFilter == data.filter;
    return GestureDetector(
      onTap: () => setState(() => _activeFilter = data.filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd + 2,
          vertical: AppTheme.spaceSm + 2,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor
              : (isDark ? AppTheme.darkCardColor : Colors.white),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isActive
                ? AppTheme.primaryColor
                : (isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.grey.shade300),
            width: 1.2,
          ),
          boxShadow: isActive ? AppTheme.softShadow1 : null,
        ),
        child: Text(
          tr(context, data.key),
          style: AppFonts.style(
            size: 12,
            weight: FontWeight.w700,
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF44403C)),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TEST CARD (modernized)
  // ===========================================================================
  Widget _buildTestCard(
    BuildContext context,
    TestModel test,
    int index,
    bool isDark,
  ) {
    // listen: TRUE — so the card rebuilds when AuthProvider changes.
    // This is CRITICAL: after a successful payment, addPurchasedTest() calls
    // notifyListeners(). Without listen:true, the card would NOT rebuild and
    // the button would stay as "Buy" even though the test was just purchased
    // — exactly the "payment success hole kichui hoi na, akhano buy dekhachche"
    // bug. With listen:true, the button flips from "Buy" to "Start Test"
    // INSTANTLY after payment success.
    final auth = Provider.of<AuthProvider>(context, listen: true);
    final user = auth.user;
    // Use the SERVER-SIDE premium status (accurate) instead of the local
    // Firestore copy (can be stale). This ensures the button label matches
    // what will actually happen when the user taps it.
    final isPremium = _effectiveIsPremium(user);
    final hasPurchasedTest =
        (user?.purchasedTests.contains(test.id) ?? false);
    // LOCAL exam-pack check (synchronous) — the Firestore-loaded
    // purchasedCategoryIds. This is the instant source that prevents the
    // "Buy" flash: even before _serverHasExamPackAccess flips to true (after
    // the 300-900ms server round-trip), this local check grants access.
    final rawCategoryId =
        (widget.categoryId != null && widget.categoryId!.isNotEmpty)
            ? widget.categoryId!
            : (widget.subject?.categoryId ?? '');
    final localHasExamPack = rawCategoryId.isNotEmpty &&
        (user?.purchasedCategoryIds.contains(rawCategoryId) ?? false);
    // Also grant access when the user owns the exam pack for this category
    // (local OR server-confirmed). Without this check, exam-pack buyers see
    // a "Buy" button on every test inside the category they already paid for.
    final hasAccess = isPremium ||
        hasPurchasedTest ||
        localHasExamPack ||
        _serverHasExamPackAccess ||
        _serverHasSubjectPackAccess;
    final isPaid = test.isPaid;
    final needsPurchase = isPaid && !hasAccess;
    // Distinguish "premium-only" (no individual price) from "buy individually".
    final isPremiumOnly = test.isPremium && test.price <= 0;
    final canBuyIndividually = test.price > 0;

    // Category accent color (for the left bar + icon tile).
    final categoryName = widget.subject?.categoryId;
    final categoryColor = AppTheme.colorFor(categoryName);

    final cardColor = isDark ? AppTheme.darkCardColor : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1917);
    final subtleTextColor =
        isDark ? Colors.white70 : const Color(0xFF57534E);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.05);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softShadow1,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // Whole card is tappable — same logic as the action button.
            // Testbook-style: tap anywhere on the card to start/buy.
            onTap: () {
              HapticFeedback.selectionClick();
              if (needsPurchase) {
                _showPurchaseSheet(context, test, user);
              } else {
                _startTest(context, test);
              }
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== Top row: icon tile + title block + badge =====
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon tile (56×56, category-tinted).
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.12),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                            color: categoryColor.withOpacity(0.28),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _emojiForTestType(test.type),
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMd),
                      // Title block (flex).
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + corner badge row.
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Hero(
                                    tag: 'test-title-${test.id}',
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: Text(
                                        lc(
                                            context, test.title, test.titleAs),
                                        style: AppFonts.style(
                                          size: 15,
                                          weight: FontWeight.w700,
                                          color: titleColor,
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppTheme.spaceSm),
                                _buildCardBadge(
                                  context: context,
                                  test: test,
                                  canBuyIndividually: canBuyIndividually,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Type · Year subtitle (category-colored).
                            Text(
                              _buildTypeYearLabel(context, test),
                              style: AppFonts.style(
                                size: 12,
                                weight: FontWeight.w600,
                                color: categoryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Completed % (if attempted).
                            if (_latestResults[test.id] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Completed \u00b7 ${_latestResults[test.id]!.percentage.round()}%',
                                style: AppFonts.style(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: AppTheme.successColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceSm),

                  // ===== Divider =====
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: borderColor,
                  ),
                  const SizedBox(height: AppTheme.spaceSm),

                  // ===== Bottom row: meta chips (left) + CTA button (right) =====
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppTheme.spaceMd,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _metaChip(
                              icon: Icons.help_outline_rounded,
                              label: '${test.questionCount}Q',
                              color: subtleTextColor,
                            ),
                            _metaChip(
                              icon: Icons.timer_outlined,
                              label: '${test.duration}m',
                              color: subtleTextColor,
                            ),
                            if (test.negativeMarking)
                              _metaChip(
                                icon: Icons.warning_amber_rounded,
                                label: tr(context, 'test_negativeMarking'),
                                color: AppTheme.warningColor,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceSm),
                      _buildCompactActionButton(
                        context: context,
                        test: test,
                        user: user,
                        needsPurchase: needsPurchase,
                        isPremiumOnly: isPremiumOnly,
                        price: test.price,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 50).ms, duration: 400.ms)
        .slideY(begin: 0.06);
  }

  String _emojiForTestType(TestType type) {
    switch (type) {
      case TestType.mock:
        return '📝';
      case TestType.previousYear:
        return '📄';
      case TestType.dailyQuiz:
        return '⚡';
      case TestType.practice:
        return '🎯';
      case TestType.subjectwise:
        return '📚';
    }
  }

  // ===========================================================================
  // CARD HELPERS (Testbook-style single-column horizontal card)
  // ===========================================================================

  /// Compact corner badge for the test card's top-right corner.
  /// Shows only the MOST important access/price signal: FREE, Premium, or ₹X.
  Widget _buildCardBadge({
    required BuildContext context,
    required TestModel test,
    required bool canBuyIndividually,
  }) {
    if (!test.isPaid) {
      return _cardCornerBadge(tr(context, 'free'), AppTheme.successColor);
    } else if (test.isPremium && !canBuyIndividually) {
      return _cardCornerBadge(
        tr(context, 'premium'),
        AppTheme.accentColor,
        isGradient: true,
      );
    } else if (canBuyIndividually) {
      return _cardCornerBadge('₹${test.price}', AppTheme.accentColor);
    }
    return const SizedBox.shrink();
  }

  Widget _cardCornerBadge(String label, Color color, {bool isGradient = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: isGradient
            ? LinearGradient(
                colors: AppTheme.accentGradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isGradient ? null : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: AppFonts.style(
          size: 10,
          weight: FontWeight.w800,
          color: isGradient ? Colors.white : color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// "Type · Year" compact subtitle for the card (e.g. "Mock · 2024").
  String _buildTypeYearLabel(BuildContext context, TestModel test) {
    final parts = <String>[];
    switch (test.type) {
      case TestType.mock:
        parts.add(tr(context, 'test_mock'));
        break;
      case TestType.previousYear:
        parts.add(tr(context, 'test_previousYear'));
        break;
      case TestType.dailyQuiz:
        parts.add(tr(context, 'daily_quiz_title'));
        break;
      case TestType.practice:
        parts.add(tr(context, 'test_mock'));
        break;
      case TestType.subjectwise:
        parts.add(tr(context, 'test_mock'));
        break;
    }
    if (test.year != null && test.year! > 0) {
      parts.add('${test.year}');
    }
    return parts.join(' · ');
  }

  /// Compact inline meta chip — used in the bottom row of the new horizontal
  /// Testbook-style card. Renders an icon + label inline (no background) so
  /// multiple chips can sit side-by-side via Wrap.
  Widget _metaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppFonts.style(
            size: 12,
            weight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Compact inline CTA button — sits at the right end of the card's bottom
  /// row. Three variants matching the access logic:
  ///   * Start Test (filled primary) — when the user has access
  ///   * Unlock Premium (outlined accent) — premium-only, no individual price
  ///   * Buy ₹X (gradient accent) — paid test that can be bought individually
  Widget _buildCompactActionButton({
    required BuildContext context,
    required TestModel test,
    required UserModel? user,
    required bool needsPurchase,
    required bool isPremiumOnly,
    required int price,
  }) {
    if (!needsPurchase) {
      return ElevatedButton.icon(
        onPressed: () => _startTest(context, test),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: Text(
          tr(context, 'test_startTest'),
          style: AppFonts.style(
            size: 13,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }
    if (isPremiumOnly) {
      return OutlinedButton.icon(
        onPressed: () => _showPurchaseSheet(context, test, user),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.accentColor,
          side: BorderSide(color: AppTheme.accentColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
        icon: const Icon(Icons.workspace_premium_rounded, size: 18),
        label: Text(
          tr(context, 'test_unlockPremium'),
          style: AppFonts.style(
            size: 13,
            weight: FontWeight.w700,
            color: AppTheme.accentColor,
          ),
        ),
      );
    }
    return _GradientButton(
      gradient: AppTheme.accentGradientColors,
      icon: Icons.shopping_cart_outlined,
      label: '${tr(context, 'test_buyNow')} ₹$price',
      onPressed: () => _showPurchaseSheet(context, test, user),
      compact: true,
    );
  }

  /// Tapped "Start Test" (or "Buy"/"Go Premium" — all routes go through here
  /// for paid tests so the server gets the final say). For FREE tests, opens
  /// immediately. For PAID tests where the user has LOCAL access (premium or
  /// purchased), navigates directly — TakeTestScreen does its own server-side
  /// check as the final gatekeeper, so skipping the check here avoids a
  /// redundant network round-trip. For PAID tests with no local access, does
  /// a server-side access check; if the backend grants access, navigates.
  /// If denied, shows the purchase sheet.
  Future<void> _startTest(BuildContext context, TestModel test) async {
    HapticFeedback.selectionClick();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    // Authoritative category id — prefer the one passed from
    // CategoryDetailScreen; fall back to the subject's categoryId field.
    final effectiveCategoryId =
        (widget.categoryId != null && widget.categoryId!.isNotEmpty)
            ? widget.categoryId
            : widget.subject?.categoryId;

    // FREE TESTS — short-circuit. If the test is neither premium nor priced,
    // there is nothing to purchase or gate. Open it immediately WITHOUT a
    // server round-trip. Guests CAN take free tests.
    if (!test.isPaid) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TestInstructionsScreen(test: test, categoryId: effectiveCategoryId)),
      );
      return;
    }

    // GUEST MODE — paid tests require an account. Send guest directly to the
    // login screen so they can sign up and then purchase / access the test.
    // This is cleaner than going through TakeTestScreen's paywall because the
    // user doesn't have an account yet — there's nothing to buy until they log in.
    if (auth.isGuest) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // PAID TESTS with LOCAL access — navigate directly. The local user model
    // says the user is premium, has purchased this test, or the exam-pack
    // check (already done on screen load) says the category is unlocked.
    // TakeTestScreen will do its own server-side check (cached, so instant)
    // as the final gatekeeper. This avoids a redundant network round-trip.
    // LOCAL exam-pack check — same logic as _buildTestCard. The Firestore-
    // loaded purchasedCategoryIds is the instant source; _serverHasExamPackAccess
    // is the server-confirmed source. Either one grants the fast-path open.
    final localExamPack = effectiveCategoryId != null &&
        effectiveCategoryId.isNotEmpty &&
        (user?.purchasedCategoryIds.contains(effectiveCategoryId) ?? false);
    final localHasAccess = _effectiveIsPremium(user) ||
        (user?.purchasedTests.contains(test.id) ?? false) ||
        localExamPack ||
        _serverHasExamPackAccess ||
        _serverHasSubjectPackAccess;
    if (localHasAccess) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TestInstructionsScreen(test: test, categoryId: effectiveCategoryId)),
      );
      return;
    }

    // PAID TESTS with no local access — the server is the single source of
    // truth. Even if we thought the user had no access, the server check here
    // is the real gatekeeper (catches entitlements granted on another device).
    try {
      final decision = await AccessService.checkTestAccess(
        test.id,
        subjectId:
            test.subjectId.isNotEmpty ? test.subjectId : widget.subject?.id,
        categoryId: effectiveCategoryId,
      );
      if (decision.allowed) {
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TestInstructionsScreen(test: test, categoryId: effectiveCategoryId)),
        );
        return;
      }
      // Denied — show purchase sheet.
      if (!context.mounted) return;
      _showPurchaseSheet(context, test, user);
    } on PaymentApiException catch (e) {
      // 404 / network — fall back to local check.
      if (!context.mounted) return;
      if (localHasAccess) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TestInstructionsScreen(test: test, categoryId: effectiveCategoryId)),
        );
      } else if (e.statusCode == 404) {
        // Backend not ready — show the friendly message.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      } else {
        _showPurchaseSheet(context, test, user);
      }
    } catch (_) {
      if (!context.mounted) return;
      if (localHasAccess) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TestInstructionsScreen(test: test, categoryId: effectiveCategoryId)),
        );
      }
    }
  }

  /// 2-option purchase sheet: Buy this test (if individually priced) / Go Premium.
  /// The old "Unlock subject pack ₹99" option was removed because subject-pack
  /// prices are not yet admin-configurable — the hardcoded ₹99 placeholder was
  /// confusing users.
  void _showPurchaseSheet(BuildContext context, TestModel test, UserModel? user) {
    // Guest / not signed in — send them to the login screen.
    // They can't purchase anything without an account.
    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final canBuyTest = test.price > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1917);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurfaceColor : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceLg,
              AppTheme.spaceMd,
              AppTheme.spaceLg,
              AppTheme.spaceLg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                    ),
                  ),
                ),
                Text(
                  tr(context, 'test_unlockTest')
                      .replaceAll('{title}', lc(context, test.title, test.titleAs)),
                  style: AppFonts.style(
                    size: 16,
                    weight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                L10nText(
                  canBuyTest
                      ? 'test_buyOrPremiumDesc'
                      : 'test_premiumOnlyDesc',
                  style: AppFonts.style(
                    size: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                if (canBuyTest) ...[
                  _sheetOption(
                    context: sheetCtx,
                    icon: Icons.shopping_cart_outlined,
                    color: AppTheme.successColor,
                    titleKey: 'test_buyThisTest',
                    subtitle:
                        '₹${test.price} · ${tr(sheetCtx, 'test_attemptAnytime')}',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _purchaseTest(context, test, user, auth);
                    },
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                ],
                _sheetOption(
                  context: sheetCtx,
                  icon: Icons.workspace_premium_rounded,
                  color: AppTheme.accentColor,
                  titleKey: 'premium_title',
                  subtitle: tr(sheetCtx, 'test_unlimitedAccess'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    // FIXED: refresh access when user returns from premium screen.
                    Navigator.pushNamed(context, '/premium').then((_) {
                      if (context.mounted) _refreshAccessStatus();
                    });
                  },
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: L10nText(
                    'test_maybeLater',
                    style: AppFonts.style(
                        size: 14, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetOption({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String titleKey,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1917);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSm + 2),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  L10nText(
                    titleKey,
                    style: AppFonts.style(
                      size: 14,
                      weight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppFonts.style(
                        size: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  /// Initiates a Razorpay payment for a single test. Shows loading indicators
  /// during the two network steps (createOrder + verifyPayment) so the user
  /// always knows what's happening. On server-verified success, writes a
  /// positive AccessDecision to the cache (so the next access check is
  /// instant), optimistically marks the test as purchased locally, and shows
  /// a success snackbar.
  ///
  /// BOTH the "Preparing payment..." and "Verifying payment..." dialogs are
  /// cancellable — the user is NEVER trapped. A 25-second safety timer
  /// force-dismisses any stuck dialog and points the user to "My Purchases"
  /// to check the payment status.
  ///
  /// IMPORTANT: a successful payment is ALWAYS processed (onSuccess runs
  /// regardless of the `cancelled` flag) — if the user dismissed the dialog
  /// but the payment actually went through, the test is still unlocked.
  void _purchaseTest(
    BuildContext context,
    TestModel test,
    UserModel user,
    AuthProvider auth,
  ) {
    final progress = PaymentProgressDialog();
    // `cancelled` only suppresses *error* snackbars after the user explicitly
    // cancelled. It does NOT block onSuccess — a payment that actually
    // succeeded must always be honoured.
    bool cancelled = false;

    void showCheckPurchasesMessage() {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text(tr(context, 'test_paymentTakingLong')),
          backgroundColor: AppTheme.warningColor,
          action: SnackBarAction(
            label: tr(context, 'profile_myPurchases'),
            textColor: Colors.white,
            onPressed: () {
              if (context.mounted) {
                Navigator.pushNamed(context, '/my-purchases');
              }
            },
          ),
        ),
      );
    }

    // Authoritative category id (see _startTest for rationale).
    final effectiveCategoryId =
        (widget.categoryId != null && widget.categoryId!.isNotEmpty)
            ? widget.categoryId
            : widget.subject?.categoryId;

    RazorpayService.startTestPurchase(
      userId: user.id,
      userName: user.name,
      userEmail: user.email ?? 'user@examvault.com',
      userPhone: user.phoneNumber ?? '9999999999',
      testId: test.id,
      testTitle: lc(context, test.title, test.titleAs),
      amount: test.price,
      subjectId:
          test.subjectId.isNotEmpty ? test.subjectId : widget.subject?.id,
      categoryId: effectiveCategoryId,
      // createOrder is about to start — show "Preparing payment..." with a
      // Cancel button so the user can abort if the network is too slow.
      onPreparing: () {
        if (cancelled) return;
        progress.show(
          context,
          message: tr(context, 'test_preparingPayment'),
          cancellable: true,
          onCancel: () => cancelled = true,
          onSafetyTimeout: showCheckPurchasesMessage,
        );
      },
      // Razorpay checkout is about to open — dismiss the "preparing" dialog.
      onCheckoutOpened: () {
        progress.dismiss();
      },
      // Razorpay checkout closed, user paid — /verify is about to run.
      // Show "Verifying payment...". Also cancellable — if the verify step
      // hangs, the user can dismiss it and check My Purchases to see if the
      // payment was captured.
      onVerifying: () {
        if (cancelled) return;
        progress.show(
          context,
          message: tr(context, 'test_verifyingPayment'),
          cancellable: true,
          cancelLabel: tr(context, 'profile_myPurchases'),
          // 60s accommodates the verify call (20s) + order-status polling
          // (up to 3 polls × ~13s) which lets the Razorpay webhook fire.
          safetyTimeout: const Duration(seconds: 60),
          onCancel: () {
            cancelled = true;
            // The payment may have been captured — point the user to My
            // Purchases so they can see the status.
            showCheckPurchasesMessage();
          },
          onSafetyTimeout: showCheckPurchasesMessage,
        );
      },
      onSuccess: (response) {
        // ALWAYS process a successful payment — even if the user dismissed
        // the dialog, the payment went through and the test must be unlocked.
        progress.dismiss();

        // Write a positive AccessDecision to the cache so the next access
        // check (when the user taps Start Test) is instant — no network
        // round-trip. This is the key fix for "payment korar por seta khulte
        // loading hoi" (opening after payment loads slowly).
        AccessService.markTestPurchased(test.id);
        // Optimistically mark the test as purchased locally AND persist to
        // Firestore so it survives app restarts / re-login. The button flips
        // from "Buy" to "Start" instantly (the card listens to AuthProvider).
        auth.addPurchasedTest(test.id);
        if (!context.mounted) return;
        // Show a PROMINENT success dialog (not a subtle snackbar). The user
        // taps "Open Test" to proceed. This fixes "payment er por kichui hoi
        // na" — the user now gets clear, unmissable feedback.
        PaymentSuccessDialog.show(
          context,
          itemName: lc(context, test.title, test.titleAs),
          amount: test.price,
          actionLabel: tr(context, 'test_openTest'),
          paymentId: response.paymentId,
        ).then((shouldOpen) {
          if (shouldOpen && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TestInstructionsScreen(test: test, categoryId: effectiveCategoryId)),
            );
          }
        });
      },
      onError: (response) {
        progress.dismiss();
        // If the user explicitly cancelled, don't show a scary "Payment
        // failed" message — they already know.
        if (cancelled) return;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${tr(context, 'test_paymentFailedPrefix')} ${response.message ?? tr(context, 'test_paymentFailedGeneric')}',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
    );
  }

  // ==================== SUBJECT PACK PURCHASE ====================

  /// Banner shown at the top of the test list when the admin has set a
  /// premiumPrice > 0 on this subject and the user hasn't bought it yet.
  /// Tapping it starts a Razorpay subject-pack purchase.
  Widget _buildSubjectPackBanner(BuildContext context, SubjectModel subject) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spaceLg,
        AppTheme.spaceMd,
        AppTheme.spaceLg,
        0,
      ),
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softShadow1,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr(context, 'test_unlockSubject')
                      .replaceAll('{subject}', lc(context, subject.name, subject.nameAs)),
                  style: AppFonts.style(
                    size: 14,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                L10nText(
                  'test_unlockSubjectDesc',
                  style: AppFonts.style(
                    size: 11,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          ElevatedButton(
            onPressed: () => _purchaseSubjectPack(context, subject),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceLg,
                vertical: AppTheme.spaceSm + 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            child: Text(
              '₹${subject.premiumPrice}',
              style: AppFonts.style(size: 14, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 450.ms)
        .slideY(begin: 0.06);
  }

  /// Initiates a Razorpay payment for a subject pack (unlocks ALL tests in
  /// this subject). Mirrors the _purchaseTest flow: progress dialogs during
  /// createOrder + verify, success dialog on success, error snackbar on fail.
  /// On success, writes a positive AccessDecision to the cache
  /// (markSubjectPackPurchased) so all tests in this subject flip to "Start"
  /// instantly — no per-test server round-trip.
  void _purchaseSubjectPack(
    BuildContext context,
    SubjectModel subject,
  ) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'test_signInToPurchase'))),
      );
      return;
    }

    final progress = PaymentProgressDialog();
    bool cancelled = false;

    void showCheckPurchasesMessage() {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text(tr(context, 'test_paymentTakingLong')),
          backgroundColor: AppTheme.warningColor,
          action: SnackBarAction(
            label: tr(context, 'profile_myPurchases'),
            textColor: Colors.white,
            onPressed: () {
              if (context.mounted) {
                Navigator.pushNamed(context, '/my-purchases');
              }
            },
          ),
        ),
      );
    }

    final effectiveCategoryId =
        (widget.categoryId != null && widget.categoryId!.isNotEmpty)
            ? widget.categoryId
            : subject.categoryId;

    RazorpayService.startSubjectPackPurchase(
      userId: user.id,
      userName: user.name,
      userEmail: user.email ?? 'user@examvault.com',
      userPhone: user.phoneNumber ?? '9999999999',
      subjectId: subject.id,
      subjectName: lc(context, subject.name, subject.nameAs),
      amount: subject.premiumPrice,
      categoryId: effectiveCategoryId,
      onPreparing: () {
        if (cancelled) return;
        progress.show(
          context,
          message: tr(context, 'test_preparingPayment'),
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
          message: tr(context, 'test_verifyingPayment'),
          cancellable: true,
          cancelLabel: tr(context, 'profile_myPurchases'),
          safetyTimeout: const Duration(seconds: 60),
          onCancel: () {
            cancelled = true;
            showCheckPurchasesMessage();
          },
          onSafetyTimeout: showCheckPurchasesMessage,
        );
      },
      onSuccess: (response) {
        progress.dismiss();
        // Write a positive AccessDecision to the cache so all tests in this
        // subject flip to "Start" instantly.
        AccessService.markSubjectPackPurchased(subject.id);
        // Flip the local flag so the banner hides + all test cards rebuild
        // with "Start" instead of "Buy".
        if (!mounted) return;
        setState(() => _serverHasSubjectPackAccess = true);
        if (!context.mounted) return;
        PaymentSuccessDialog.show(
          context,
          itemName:
              '${tr(context, 'test_subjectPackPrefix')}${lc(context, subject.name, subject.nameAs)}',
          amount: subject.premiumPrice,
          actionLabel: tr(context, 'done'),
          paymentId: response.paymentId,
        );
      },
      onError: (response) {
        progress.dismiss();
        if (cancelled) return;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${tr(context, 'test_paymentFailedPrefix')} ${response.message ?? tr(context, 'test_paymentFailedGeneric')}',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
    );
  }
}

// =============================================================================
// v2 HELPERS
// =============================================================================

/// Filter chip enum (All / Free / Premium / Mock / Previous Year).
enum _TestFilter { all, free, premium, mock, previousYear }

/// Tiny data holder for a filter chip's l10n key + enum value.
class _FilterChipData {
  final String key;
  final _TestFilter filter;
  const _FilterChipData({required this.key, required this.filter});
}

/// Amber-gradient "Buy Now ₹X" button. ElevatedButton doesn't support
/// gradients directly, so we use a Material + Ink + InkWell + gradient.
/// Pass `compact: true` for the inline card-CTA variant (height 36, smaller
/// icon/font/padding) so it lines up with the meta chips on the bottom row.
class _GradientButton extends StatelessWidget {
  final List<Color> gradient;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool compact;

  const _GradientButton({
    required this.gradient,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double height = compact ? 36 : 44;
    final double iconSize = compact ? 18 : 20;
    final double fontSize = compact ? 13 : 14;
    final double horizontalPadding =
        compact ? AppTheme.spaceMd : AppTheme.spaceLg;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Container(
            height: height,
            alignment: Alignment.center,
            padding:
                EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: iconSize, color: Colors.white),
                const SizedBox(width: AppTheme.spaceSm),
                Text(
                  label,
                  style: AppFonts.style(
                    size: fontSize,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
