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
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/subject_model.dart';
import '../../models/test_model.dart';
import '../../models/user_model.dart';
import '../../services/access_service.dart';
import '../../services/firestore_service.dart';
import '../../services/payment_api_service.dart';
import '../../services/razorpay_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/payment_progress_dialog.dart';
import '../../widgets/payment_success_dialog.dart';
import 'take_test_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _refreshAccessStatus();
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
    // The local model is set by markPremium() on purchase and persisted to
    // Firestore, so it is reliable across restarts.
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
      if (decision.allowed) {
        setState(() => _serverHasExamPackAccess = true);
      }
    } catch (_) {
      // Silently ignore — the server-side per-test access check in
      // _startTest will still catch exam-pack ownership correctly.
    }
  }

  /// Effective premium status: server-side if available, else local fallback.
  bool _effectiveIsPremium(UserModel? user) {
    if (_serverIsPremium != null) return _serverIsPremium!;
    return user?.isPremium ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject?.name ?? 'Tests'),
      ),
      body: StreamBuilder<List<TestModel>>(
        stream: FirestoreService.getTestsStream(
          subjectId: widget.subject?.id,
          isPublished: true,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load tests.\nPlease check your connection and retry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tests available'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final test = snapshot.data![index];
              return _buildTestCard(context, test);
            },
          );
        },
      ),
    );
  }

  Widget _buildTestCard(BuildContext context, TestModel test) {
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
    // Also grant access when the user owns the exam pack for this category.
    // Without this check, exam-pack buyers see a "Buy" button on every test
    // inside the category they already paid for.
    final hasAccess = isPremium || hasPurchasedTest || _serverHasExamPackAccess;
    final isPaid = test.isPaid;
    final needsPurchase = isPaid && !hasAccess;
    // Distinguish "premium-only" (no individual price) from "buy individually".
    final isPremiumOnly = test.isPremium && test.price <= 0;
    final canBuyIndividually = test.price > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + price/premium badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    test.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (test.isPremium)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.workspace_premium,
                            color: AppTheme.accentColor, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          canBuyIndividually ? '₹${test.price}' : 'Premium',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (test.price > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₹${test.price}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.successColor,
                      ),
                    ),
                  )
                else
                  // Explicit "FREE" badge so users can see at a glance that
                  // this test requires no payment or premium subscription.
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.successColor.withOpacity(0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      'FREE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Test meta info
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildInfo(
                    Icons.help_outline, '${test.questionCount} Questions'),
                _buildInfo(Icons.timer, '${test.duration} min'),
                _buildInfo(Icons.star, '${test.totalMarks} marks'),
                _buildInfo(
                    Icons.trending_up, '${test.attemptCount} attempts'),
              ],
            ),
            const SizedBox(height: 16),
            // Action button — Buy / Go Premium / Start depending on access.
            // For paid tests the button reflects the server-side access state
            // so the label always matches what happens on tap.
            SizedBox(
              width: double.infinity,
              height: 44,
              child: !needsPurchase
                  ? ElevatedButton.icon(
                      onPressed: () => _startTest(context, test),
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text('Start Test'),
                    )
                  : isPremiumOnly
                      ? ElevatedButton.icon(
                          onPressed: () =>
                              _showPurchaseSheet(context, test, user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.workspace_premium,
                              size: 20),
                          label: const Text('Go Premium'),
                        )
                      : ElevatedButton.icon(
                          onPressed: () =>
                              _showPurchaseSheet(context, test, user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.shopping_cart_outlined,
                              size: 20),
                          label: Text('Buy for ₹${test.price}'),
                        ),
            ),
            // Hint text for paid tests
            if (needsPurchase)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  isPremiumOnly
                      ? 'Subscribe to Premium to attempt this test.'
                      : 'Buy this test or upgrade to Premium.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
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
        MaterialPageRoute(builder: (_) => TakeTestScreen(test: test, categoryId: effectiveCategoryId)),
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
    final localHasAccess = _effectiveIsPremium(user) ||
        (user?.purchasedTests.contains(test.id) ?? false) ||
        _serverHasExamPackAccess;
    if (localHasAccess) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TakeTestScreen(test: test, categoryId: effectiveCategoryId)),
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
          MaterialPageRoute(builder: (_) => TakeTestScreen(test: test, categoryId: effectiveCategoryId)),
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
          MaterialPageRoute(builder: (_) => TakeTestScreen(test: test, categoryId: effectiveCategoryId)),
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
          MaterialPageRoute(builder: (_) => TakeTestScreen(test: test, categoryId: effectiveCategoryId)),
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

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Unlock "${test.title}"',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  canBuyTest
                      ? 'Buy this test or upgrade to Premium. All payments are secure & verified.'
                      : 'Upgrade to Premium for unlimited access. All payments are secure & verified.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                if (canBuyTest) ...[
                  _sheetOption(
                    icon: Icons.shopping_cart_outlined,
                    color: AppTheme.successColor,
                    title: 'Buy this test',
                    subtitle: '₹${test.price} · attempt anytime',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _purchaseTest(context, test, user, auth);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                _sheetOption(
                  icon: Icons.workspace_premium,
                  color: AppTheme.accentColor,
                  title: 'Go Premium',
                  subtitle: 'Unlimited access to everything',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    // FIXED: refresh access when user returns from premium screen.
                    Navigator.pushNamed(context, '/premium').then((_) {
                      if (context.mounted) _refreshAccessStatus();
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: const Text('Maybe later'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
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
          content: const Text(
            'Payment is taking longer than expected. Check "My Purchases" to see if it succeeded.',
          ),
          backgroundColor: AppTheme.warningColor,
          action: SnackBarAction(
            label: 'My Purchases',
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
      testTitle: test.title,
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
          message: 'Preparing payment...',
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
          message: 'Verifying payment...',
          cancellable: true,
          cancelLabel: 'Check My Purchases',
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
          itemName: test.title,
          amount: test.price,
          actionLabel: 'Open Test',
          paymentId: response.paymentId,
        ).then((shouldOpen) {
          if (shouldOpen && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TakeTestScreen(test: test, categoryId: effectiveCategoryId)),
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
                'Payment failed: ${response.message ?? 'Please try again.'}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
    );
  }

  Widget _buildInfo(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
