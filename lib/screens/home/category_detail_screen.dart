// =============================================================================
// ExamVault - Category Detail Screen (shows subjects in a category)
// =============================================================================
// v1.23+ — server-side access check. Before listing subjects, this screen
// calls AccessService.checkCategoryAccess(category.id). If the backend says
// the user lacks access, a paywall is shown with two options:
//   1. "Unlock this exam (₹X)" → RazorpayService.startExamPackPurchase
//   2. "Go Premium"            → /premium
// If the backend endpoint is not ready yet (404), the screen falls back to
// the legacy local check (auth.isPremium) so the app keeps working.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../models/subject_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/access_service.dart';
import '../../services/firestore_service.dart';
import '../../services/payment_api_service.dart';
import '../../services/razorpay_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/payment_progress_dialog.dart';
import '../../widgets/payment_success_dialog.dart';
import '../tests/test_list_screen.dart';

enum _AccessState { loading, allowed, denied, rollingOut }

class CategoryDetailScreen extends StatefulWidget {
  final CategoryModel category;

  const CategoryDetailScreen({super.key, required this.category});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  /// Bumped on pull-to-refresh to force the StreamBuilder to re-subscribe.
  int _reloadKey = 0;

  /// Server-side access state for this category.
  _AccessState _accessState = _AccessState.loading;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    // Fast path: non-premium categories are always open.
    if (!widget.category.isPremium) {
      if (!mounted) return;
      setState(() => _accessState = _AccessState.allowed);
      return;
    }
    try {
      final decision =
          await AccessService.checkCategoryAccess(widget.category.id);
      if (!mounted) return;
      setState(() {
        _accessState =
            decision.allowed ? _AccessState.allowed : _AccessState.denied;
      });
    } on PaymentApiException catch (e) {
      // 404 or other API errors. Fall back to local isPremium check so the
      // app keeps working for users who are already premium locally. If the
      // user is NOT locally premium, show the paywall (denied) instead of a
      // confusing "rolling out" message — the user should be able to buy the
      // exam pack regardless of backend access-check availability.
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      setState(() {
        _accessState =
            auth.isPremium ? _AccessState.allowed : _AccessState.denied;
      });
    } catch (_) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      setState(() {
        _accessState =
            auth.isPremium ? _AccessState.allowed : _AccessState.denied;
      });
    }
  }

  /// Kick off an Exam Pack purchase for this category. Shows loading indicators
  /// during the two network steps (createOrder + verifyPayment) so the user
  /// always knows what's happening — fixes "app hang hoye geche" when tapping
  /// "Unlock this exam" with no feedback. On success, shows a prominent success
  /// dialog (not a subtle snackbar), clears the access cache, and re-checks so
  /// the paywall flips to the subjects list.
  ///
  /// BOTH the "Preparing payment..." and "Verifying payment..." dialogs are
  /// cancellable — the user is NEVER trapped. A safety timer force-dismisses
  /// any stuck dialog and points the user to "My Purchases".
  void _startExamPackPurchase() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to make a purchase.')),
      );
      return;
    }
    if (widget.category.premiumPrice <= 0) {
      // No exam-pack price configured → fall back to Premium.
      Navigator.pushNamed(context, '/premium');
      return;
    }

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
      categoryId: widget.category.id,
      categoryName: widget.category.name,
      amount: widget.category.premiumPrice,
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
      // Show "Verifying payment...". Also cancellable.
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
        // Backend confirmed grant — clear cache + refresh user + re-check.
        AccessService.clearCache();
        auth.loadUserData();
        if (!mounted) return;
        // Show a PROMINENT success dialog (not a subtle snackbar). The user
        // taps "Open Exam" to proceed. This fixes "payment er por kichui hoi
        // na" — the user now gets clear, unmissable feedback.
        PaymentSuccessDialog.show(
          context,
          itemName: widget.category.name,
          amount: widget.category.premiumPrice,
          actionLabel: 'Open Exam',
          paymentId: response.paymentId,
        ).then((_) {
          if (mounted) {
            // Re-check access so the paywall flips to the subjects list.
            _checkAccess();
          }
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
            content: Text(response.message ?? 'Payment failed. Please try again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.categoryColors[widget.category.name] ?? AppTheme.primaryColor,
                  (AppTheme.categoryColors[widget.category.name] ?? AppTheme.primaryColor)
                      .withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.category.icon ?? '📚',
                      style: const TextStyle(fontSize: 40),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.category.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.category.subjectCount} Subjects Available',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.category.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.category.description!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Body — depends on the server-side access decision.
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_accessState) {
      case _AccessState.loading:
        return const Center(child: CircularProgressIndicator());
      case _AccessState.allowed:
        return _buildSubjectsList();
      case _AccessState.rollingOut:
        return _buildRollingOutState();
      case _AccessState.denied:
        return _buildPaywall();
    }
  }

  /// Subjects list — same as before, shown when access is granted (or the
  /// category is not premium).
  Widget _buildSubjectsList() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _reloadKey++);
        // Also re-check access on pull-to-refresh.
        await _checkAccess();
        await Future.delayed(const Duration(milliseconds: 400));
      },
      child: StreamBuilder<List<SubjectModel>>(
        key: ValueKey('subjects-${_reloadKey}'),
        stream: FirestoreService.getSubjectsStream(
          categoryId: widget.category.id,
          categoryName: widget.category.name,
          categorySlug: widget.category.slug,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final subject = snapshot.data![index];
              return _buildSubjectCard(context, subject);
            },
          );
        },
      ),
    );
  }

  /// Paywall shown when the backend denies access to this premium category.
  /// Two CTAs: "Unlock this exam (₹X)" (Exam Pack purchase) and "Go Premium".
  Widget _buildPaywall() {
    final canBuyExamPack = widget.category.premiumPrice > 0;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock,
              size: 56, color: AppTheme.accentColor),
        ),
        const SizedBox(height: 20),
        const Text(
          'Premium Exam Pack',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          canBuyExamPack
              ? 'Unlock "${widget.category.name}" and all its tests for ₹${widget.category.premiumPrice}, or upgrade to Premium for unlimited access.'
              : 'Subscribe to Premium to unlock "${widget.category.name}" and all its tests.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Text(
          '✓ All mock tests in this exam\n✓ Detailed solutions\n✓ Performance analytics',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 24),
        if (canBuyExamPack) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _startExamPackPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.lock_open),
              label: Text('Unlock this exam (₹${widget.category.premiumPrice})'),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/premium'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentColor,
              side: const BorderSide(color: AppTheme.accentColor),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.workspace_premium),
            label: const Text('Go Premium'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Maybe later'),
        ),
      ],
    );
  }

  Widget _buildRollingOutState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.hourglass_top, size: 56, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Text(
          'This feature is being rolled out.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Please update the app soon to access premium content in ${widget.category.name}.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/premium'),
          icon: const Icon(Icons.workspace_premium),
          label: const Text('Explore Premium'),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Text(
          'Couldn\'t load subjects',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Please check your internet connection and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => setState(() => _reloadKey++),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Text(
          'No subjects available yet',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Subjects for ${widget.category.name} will appear here. Pull down to refresh.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => setState(() => _reloadKey++),
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildSubjectCard(BuildContext context, SubjectModel subject) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              subject.icon ?? '📚',
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          subject.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subject.description != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subject.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${subject.testCount} Tests',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TestListScreen(subject: subject),
            ),
          );
        },
      ),
    );
  }
}
