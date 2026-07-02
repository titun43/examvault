// =============================================================================
// ExamVault - Test List Screen (Tests in a subject OR Test details)
// Shows the test's price (if set by admin) and a Buy/Start button based on
// the user's access: premium users and already-purchased tests → Start;
// paid unpurchased tests → Buy ₹X (Razorpay per-test purchase).
//
// v1.27+ — SERVER-SIDE PREMIUM CHECK. The button label now reflects the
// server's view of the user's premium status (not the potentially-stale
// Firestore copy). On screen load we call AccessService.checkPremiumOnly()
// which hits /api/payments/access-check?type=all. The result is cached for
// 60s by AccessService, so scrolling / re-opening doesn't re-hit the API.
// This fixes the bug where the button showed "Start Test" (because the local
// Firestore user.isPremium was stale/wrong) but clicking it showed the
// purchase sheet (because the server correctly denied access).
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
import 'take_test_screen.dart';

class TestListScreen extends StatefulWidget {
  final SubjectModel? subject;
  final String? testId;

  const TestListScreen({
    super.key,
    this.subject,
    this.testId,
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

  @override
  void initState() {
    super.initState();
    _refreshPremiumStatus();
  }

  /// Fetch the server-side premium status. On success, updates
  /// [_serverIsPremium] and rebuilds. On failure, leaves it null (the UI
  //  falls back to the local user.isPremium).
  Future<void> _refreshPremiumStatus() async {
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
        _serverIsPremium = null; // unknown — fall back to local
        _premiumChecking = false;
      });
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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    // Use the SERVER-SIDE premium status (accurate) instead of the local
    // Firestore copy (can be stale). This ensures the button label matches
    // what will actually happen when the user taps it.
    final isPremium = _effectiveIsPremium(user);
    final hasPurchasedTest =
        (user?.purchasedTests.contains(test.id) ?? false);
    final hasAccess = isPremium || hasPurchasedTest;
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
  /// immediately. For PAID tests, does a server-side access check; if the
  /// backend grants access, navigates to TakeTestScreen. If denied, shows the
  /// purchase sheet.
  Future<void> _startTest(BuildContext context, TestModel test) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    // FREE TESTS — short-circuit. If the test is neither premium nor priced,
    // there is nothing to purchase or gate. Open it immediately WITHOUT a
    // server round-trip.
    if (!test.isPaid) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TakeTestScreen(test: test)),
      );
      return;
    }

    // PAID TESTS — the server is the single source of truth. Even if the
    // button said "Start Test" (because we thought the user had access),
    // the server check here is the real gatekeeper. This catches any stale
    // local state.
    try {
      final decision = await AccessService.checkTestAccess(
        test.id,
        subjectId:
            test.subjectId.isNotEmpty ? test.subjectId : widget.subject?.id,
        categoryId: widget.subject?.categoryId,
      );
      if (decision.allowed) {
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TakeTestScreen(test: test)),
        );
        return;
      }
      // Denied — show purchase sheet.
      if (!context.mounted) return;
      _showPurchaseSheet(context, test, user);
    } on PaymentApiException catch (e) {
      // 404 / network — fall back to local check.
      if (!context.mounted) return;
      final localHasAccess = _effectiveIsPremium(user) ||
          (user?.purchasedTests.contains(test.id) ?? false);
      if (localHasAccess) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TakeTestScreen(test: test)),
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
      final localHasAccess = _effectiveIsPremium(user) ||
          (user?.purchasedTests.contains(test.id) ?? false);
      if (localHasAccess) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TakeTestScreen(test: test)),
        );
      }
    }
  }

  /// 2-option purchase sheet: Buy this test (if individually priced) / Go Premium.
  /// The old "Unlock subject pack ₹99" option was removed because subject-pack
  /// prices are not yet admin-configurable — the hardcoded ₹99 placeholder was
  /// confusing users.
  void _showPurchaseSheet(BuildContext context, TestModel test, UserModel? user) {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to purchase tests.')),
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
                    Navigator.pushNamed(context, '/premium');
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

  /// Initiates a Razorpay payment for a single test. On server-verified
  /// success, clears the access cache, optimistically marks the test as
  /// purchased locally, and refreshes the premium status from the server.
  void _purchaseTest(
    BuildContext context,
    TestModel test,
    UserModel user,
    AuthProvider auth,
  ) {
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
      categoryId: widget.subject?.categoryId,
      onSuccess: (response) {
        // Clear the access-check cache so the next open reflects the new
        // entitlement, and optimistically mark the test as purchased locally
        // so the button flips from "Buy" to "Start" instantly.
        AccessService.clearCache();
        auth.addPurchasedTest(test.id);
        auth.loadUserData(); // best-effort refresh in the background
        // Re-fetch server-side premium status in case this purchase also
        // granted premium (it shouldn't for a test purchase, but the refresh
        // is cheap and keeps state consistent).
        _refreshPremiumStatus();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment successful! "${test.title}" unlocked.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      },
      onError: (response) {
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
