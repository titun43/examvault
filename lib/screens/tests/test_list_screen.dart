// =============================================================================
// ExamVault - Test List Screen (Tests in a subject OR Test details)
// Shows the test's price (if set by admin) and a Buy/Start button based on
// the user's access: premium users and already-purchased tests → Start;
// paid unpurchased tests → Buy ₹X (Razorpay per-test purchase).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/subject_model.dart';
import '../../models/test_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
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
                if (isPremium)
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
                          'Premium',
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
            // Action button — Buy or Start depending on access
            SizedBox(
              width: double.infinity,
              height: 44,
              child: needsPurchase
                  ? ElevatedButton.icon(
                      onPressed: () => _purchaseTest(context, test, user),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                      label: Text('Buy for ₹${test.price}'),
                    )
                  : ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TakeTestScreen(test: test),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text('Start Test'),
                    ),
            ),
            // Hint text for paid tests
            if (needsPurchase)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  isPaid
                      ? 'Buy this test to attempt it, or upgrade to Premium for unlimited access.'
                      : '',
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

  /// Initiates a Razorpay payment for a single test. On success, adds the test
  /// ID to the user's purchasedTests list (handled in RazorpayService) and
  /// refreshes the AuthProvider so the UI updates.
  void _purchaseTest(BuildContext context, TestModel test, UserModel? user) {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to purchase tests.')),
      );
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    RazorpayService.startTestPurchase(
      userId: user.id,
      userName: user.name,
      userEmail: user.email ?? 'user@examvault.com',
      userPhone: user.phoneNumber ?? '9999999999',
      testId: test.id,
      testTitle: test.title,
      amount: test.price,
      onSuccess: (response) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment successful! "${test.title}" unlocked.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Refresh user data so purchasedTests is up-to-date and the button
        // flips from "Buy" to "Start".
        auth.loadUserData();
      },
      onError: (response) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${response.message}'),
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
