// =============================================================================
// ExamVault - Test List Screen (Tests in a subject OR Test details)
// Shows the test's price (if set by admin) and a Buy/Start button based on
// the user's access: premium users and already-purchased tests → Start;
// paid unpurchased tests → Buy ₹X (Razorpay per-test purchase).
//
// v1.23+ — server-side access check. Before starting a test, the app calls
// AccessService.checkTestAccess(). If the backend denies access, a 3-option
// purchase sheet is shown: Buy this test / Unlock subject pack / Go Premium.
// If the access-check endpoint 404s (backend not ready), the screen falls
// back to the legacy local check (user.isPremium || user.hasTestAccess).
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

class TestListScreen extends StatelessWidget {
  final SubjectModel? subject;
  final String? testId;

  const TestListScreen({
    super.key,
    this.subject,
    this.testId,
  });

  /// Default price for "Unlock subject pack" — used as a placeholder until
  /// subject-pack products are admin-configurable. The backend's create-order
  /// endpoint can override/validate this against a product config.
  static const int _defaultSubjectPackPrice = 99;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(subject?.name ?? 'Tests'),
      ),
      body: StreamBuilder<List<TestModel>>(
        stream: FirestoreService.getTestsStream(
          subjectId: subject?.id,
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
    final isPremium = user?.isPremium ?? false;
    final hasAccess = isPremium || (user?.hasTestAccess(test.id) ?? false);
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
                      : 'Buy this test, unlock the subject pack, or upgrade to Premium.',
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

  /// Tapped "Start Test". Does a server-side access check; if the backend
  /// grants access, navigates to TakeTestScreen. If denied, shows the
  /// 3-option purchase sheet. On 404 / network error, falls back to the
  /// legacy local check.
  Future<void> _startTest(BuildContext context, TestModel test) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    try {
      final decision = await AccessService.checkTestAccess(
        test.id,
        subjectId: test.subjectId.isNotEmpty ? test.subjectId : subject?.id,
        categoryId: subject?.categoryId,
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
      final localHasAccess =
          (user?.isPremium ?? false) || (user?.hasTestAccess(test.id) ?? false);
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
      final localHasAccess =
          (user?.isPremium ?? false) || (user?.hasTestAccess(test.id) ?? false);
      if (localHasAccess) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TakeTestScreen(test: test)),
        );
      }
    }
  }

  /// 3-option purchase sheet: Buy this test / Unlock subject pack / Go Premium.
  void _showPurchaseSheet(BuildContext context, TestModel test, UserModel? user) {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to purchase tests.')),
      );
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final subjectName = subject?.name ?? 'this subject';
    final canBuyTest = test.price > 0;
    final canUnlockSubjectPack = subject != null;

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
                  'Pick the option that works for you. All payments are secure & verified.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                if (canBuyTest)
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
                if (canUnlockSubjectPack) ...[
                  if (canBuyTest) const SizedBox(height: 8),
                  _sheetOption(
                    icon: Icons.library_books,
                    color: AppTheme.infoColor,
                    title: 'Unlock subject pack',
                    subtitle:
                        '₹$_defaultSubjectPackPrice · all tests in $subjectName',
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _purchaseSubjectPack(context, user, auth);
                    },
                  ),
                ],
                if (canBuyTest || canUnlockSubjectPack) const SizedBox(height: 8),
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
  /// success, clears the access cache and refreshes the user so the button
  /// flips from "Buy" to "Start".
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
      subjectId: test.subjectId.isNotEmpty ? test.subjectId : subject?.id,
      categoryId: subject?.categoryId,
      onSuccess: (response) {
        AccessService.clearCache();
        auth.loadUserData();
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

  /// Initiates a Razorpay payment for a subject pack.
  void _purchaseSubjectPack(
    BuildContext context,
    UserModel user,
    AuthProvider auth,
  ) {
    if (subject == null) return;
    RazorpayService.startSubjectPackPurchase(
      userId: user.id,
      userName: user.name,
      userEmail: user.email ?? 'user@examvault.com',
      userPhone: user.phoneNumber ?? '9999999999',
      subjectId: subject!.id,
      subjectName: subject!.name,
      amount: _defaultSubjectPackPrice,
      categoryId: subject!.categoryId,
      onSuccess: (response) {
        AccessService.clearCache();
        auth.loadUserData();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Subject pack unlocked: ${subject!.name}. Enjoy!'),
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
