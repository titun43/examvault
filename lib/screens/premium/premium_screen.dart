// =============================================================================
// ExamVault - Premium/Payment Screen (Razorpay)
// Premium plans are admin-controllable: this screen fetches them from the
// `premium_plans` Firestore collection. If there are no plans in Firestore,
// the screen shows an empty state — it NEVER shows fake/hardcoded plans.
//
// Guest handling: a guest (browsing without signing in) can reach this screen
// from several entry points. The Subscribe button is replaced with a
// "Sign In to Continue" prompt for guests — silently returning from
// _startPayment (the old behaviour) made the button feel dead.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/access_service.dart';
import '../../services/razorpay_service.dart';
import '../../services/firestore_service.dart';
import '../../models/premium_plan_model.dart';
import '../../widgets/payment_progress_dialog.dart';
import '../../widgets/payment_success_dialog.dart';
import '../auth/login_screen.dart';
import '../support/help_support_screen.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlanIndex = 1; // Default: Quarterly (popular)
  List<Map<String, dynamic>> _plans = const [];
  bool _isLoadingPlans = true;

  // Issue #23: Restore Purchases in-flight flag. While true the Restore
  // button shows a spinner and is disabled.
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  /// Loads premium plans from Firestore. Shows an empty state if Firestore
  /// has no plans — NEVER substitutes hardcoded/fake plans.
  Future<void> _loadPlans() async {
    List<Map<String, dynamic>> plans = [];
    try {
      final fetched = await FirestoreService.getActivePremiumPlans();
      if (fetched.isNotEmpty) {
        plans = fetched.map(_planToMap).toList();
      }
    } catch (_) {
      // Swallow — plans stays empty, empty state will be shown.
    }
    if (!mounted) return;
    setState(() {
      _plans = plans;
      // Clamp the selected index to the available range. If a "popular" plan
      // exists, prefer it; otherwise default to the first plan.
      final popularIdx = plans.indexWhere((p) => p['isPopular'] == true);
      if (popularIdx >= 0) {
        _selectedPlanIndex = popularIdx;
      } else if (_selectedPlanIndex >= plans.length) {
        _selectedPlanIndex = 0;
      }
      _isLoadingPlans = false;
    });
  }

  /// Converts a Firestore-fetched PremiumPlanModel into the map shape the UI
  /// expects (same keys as the default plans below).
  static Map<String, dynamic> _planToMap(PremiumPlanModel p) {
    return {
      'name': p.name,
      'price': p.price,
      'duration': p.durationLabel.isNotEmpty
          ? p.durationLabel
          : '${p.durationMonths} Month${p.durationMonths == 1 ? '' : 's'}',
      'planId': p.planId,
      'months': p.durationMonths,
      'features': p.features.isNotEmpty
          ? p.features
          : <String>['All Premium Tests', 'Detailed Solutions'],
      if (p.isPopular) 'isPopular': true,
      if (p.description != null && p.description!.isNotEmpty)
        'discount': p.description,
    };
  }

  // ==================== Issue #23: Restore Purchases + Manage Subscription ====================
  // Razorpay webhooks can fail (misconfigured URL, Neon DB hiccup, etc.),
  // leaving a user who ACTUALLY paid without premium in the local cache.
  // "Restore Purchases" lets them force a re-fetch from the backend:
  //   1. Clear the in-memory AccessService cache (so the next check hits
  //      the network instead of returning a stale DENIED decision).
  //   2. Reload the user's data from the backend (loadUserData syncs the
  //      real-time premium status from Neon DB via the auth listener).
  //   3. Hit AccessService.checkPremiumOnly() for an authoritative fresh
  //      decision from /api/payments/access-check.
  //   4. If allowed → "Premium restored" SnackBar; else "No active
  //      subscription found".
  Future<void> _restorePurchases() async {
    if (_isRestoring) return;
    setState(() => _isRestoring = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: L10nText('premium_restore_loading'),
        duration: const Duration(seconds: 30),
      ),
    );
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      // 1. Invalidate the in-memory access cache for this user.
      AccessService.clearCache();
      // 2. Reload the user's data from the backend (Firestore + Neon sync).
      await auth.loadUserData();
      // 3. Authoritative premium check from the access-check endpoint.
      bool restored = false;
      try {
        final decision = await AccessService.checkPremiumOnly();
        restored = decision.allowed;
      } catch (_) {
        // 404 (backend not built) or network — fall back to the user-model
        // flag set by loadUserData above.
        restored = auth.isPremium;
      }
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: L10nText(restored
              ? 'premium_restore_success'
              : 'premium_restore_none'),
          backgroundColor: restored
              ? AppTheme.successColor
              : AppTheme.warningColor,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: L10nText('premium_restore_none'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  /// "Manage Subscription" — for now just shows a SnackBar directing the user
  /// to support. A full implementation would deep-link to a subscription-
  /// management page (Play Console / Razorpay hosted page).
  void _manageSubscription() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: L10nText('premium_manage_msg'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Builds the "You're a Premium member" banner shown above the plans list
  /// when the user is already premium (Issue #23). Shows the expiry date if
  /// available, plus a "Manage Subscription" text button.
  Widget _buildCurrentPlanBanner(bool isPremium, DateTime? expiry) {
    if (!isPremium) return const SizedBox.shrink();
    final String msg = expiry != null
        ? tr(context, 'premium_current_plan_msg')
            .replaceAll('{date}', DateFormat('dd MMM yyyy').format(expiry))
        : tr(context, 'premium_current_plan_no_expiry');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.successColor,
            AppTheme.successColor.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.successColor.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded,
                  color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: L10nText(
                  'premium_current_plan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            msg,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          // Manage link — text button aligned to the start.
          TextButton.icon(
            onPressed: _manageSubscription,
            icon: const Icon(Icons.settings_rounded,
                color: Colors.white, size: 16),
            label: L10nText('premium_manage',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                )),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: Alignment.centerLeft,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth so the UI rebuilds when the user signs in/out. Guests see
    // a "Sign In to Continue" prompt instead of the Subscribe button.
    final auth = context.watch<AuthProvider>();
    // Issue #23: capture the premium status + expiry for the banner + the
    // Subscribe-button gating.
    final bool isAlreadyPremium = auth.isPremium;
    final DateTime? premiumExpiry = auth.user?.subscriptionExpiry;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ExamVault Premium'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  Icon(Icons.workspace_premium, color: Colors.white, size: 60),
                  SizedBox(height: 16),
                  Text(
                    'Unlock ExamVault Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Get unlimited access to premium mock tests,\ndetailed solutions, and much more!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Features list
            const Text(
              'Premium Features',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...AppConfig.premiumFeatures.map((feature) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppTheme.successColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(feature)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            // Plans
            const Text(
              'Choose Your Plan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            // Issue #23: "Current Plan" banner — shown only when the user is
            // already premium. Sits above the plans list so the user sees
            // their active status first, before being tempted to re-subscribe
            // (which would be a double-charge).
            _buildCurrentPlanBanner(isAlreadyPremium, premiumExpiry),
            if (_isLoadingPlans)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_plans.isEmpty)
              // Empty state — no plans configured in the admin panel.
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.card_giftcard,
                        size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      'No Plans Available Right Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We are updating our premium plans.\nPlease check back later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              ...List.generate(_plans.length, (index) {
                final plan = _plans[index];
                return _buildPlanCard(plan, index);
              }),
              const SizedBox(height: 24),
              // Subscribe / Sign-in CTA. Guests get a sign-in prompt because
              // a purchase requires a Firebase UID. The old code silently
              // returned from _startPayment when auth.user was null, which
              // made the button feel completely dead.
              if (auth.isGuest) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.warningColor.withOpacity(0.45)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline,
                          color: AppTheme.warningColor, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Sign in to subscribe to Premium and unlock all features.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In to Continue'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ] else if (isAlreadyPremium)
                // Issue #23: user is already premium — DISABLE the Subscribe
                // button to prevent a double-charge. Show a "Current Plan"
                // label instead of the Subscribe CTA.
                ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.successColor.withOpacity(0.15),
                    foregroundColor: AppTheme.successColor,
                    disabledBackgroundColor:
                        AppTheme.successColor.withOpacity(0.15),
                    disabledForegroundColor: AppTheme.successColor,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 20),
                      const SizedBox(width: 8),
                      L10nText('premium_current_plan'),
                    ],
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _startPayment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Subscribe to ${_plans[_selectedPlanIndex]['name']} • ₹${_plans[_selectedPlanIndex]['price']}',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
            const SizedBox(height: 16),
            // Payment info
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'Secure payment via Razorpay',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Terms
            Text(
              'Subscription will be charged to your account. '
              'Cancel anytime from your profile. '
              'By subscribing, you agree to our Terms & Privacy Policy.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Issue #23: Restore Purchases — lets users re-fetch their active
            // subscription from the backend if a webhook failed / they
            // reinstalled the app. Always shown (not gated on isPremium)
            // because a user with a lapsed cache who IS premium needs this
            // to recover.
            OutlinedButton.icon(
              onPressed: _isRestoring ? null : _restorePurchases,
              icon: _isRestoring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore_rounded),
              label: L10nText('premium_restore'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade400),
                foregroundColor: Colors.grey.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan, int index) {
    final isSelected = _selectedPlanIndex == index;
    final isPopular = plan['isPopular'] == true;
    final hasDiscount = plan['discount'] != null;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.05)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isPopular) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'POPULAR',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          if (hasDiscount) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                plan['discount'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${plan['price']}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '/ ${plan['duration']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(
              (plan['features'] as List).length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 36),
                child: Row(
                  children: [
                    const Icon(Icons.check,
                        size: 14, color: AppTheme.successColor),
                    const SizedBox(width: 8),
                    Text(
                      plan['features'][i],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startPayment() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    // Guest guard. The old code silently `return`ed here, which made the
    // Subscribe button feel dead — the user tapped it and literally
    // nothing happened. Now the build method replaces the button with a
    // Sign-In prompt for guests, so this branch is only hit if the user
    // somehow taps before a rebuild. Belt-and-braces: show a snackbar too.
    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please sign in to subscribe to Premium.'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Sign In',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ),
      );
      return;
    }
    if (_plans.isEmpty) return;

    final selectedPlan = _plans[_selectedPlanIndex];

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

    RazorpayService.startPayment(
      userId: auth.user!.id,
      userName: auth.user!.name,
      userEmail: auth.user!.email ?? 'user@examvault.com',
      userPhone: auth.user?.phoneNumber ?? '',
      amount: selectedPlan['price'] as int,
      planId: selectedPlan['planId'] as String,
      planName: selectedPlan['name'] as String,
      durationMonths: selectedPlan['months'] as int,
      planTier: selectedPlan['name'] as String,
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
          // 60s accommodates the verify call (20s) + order-status polling
          // (up to 3 polls × ~13s) which lets the Razorpay webhook fire.
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
        // the dialog, the payment went through and premium must be activated.
        progress.dismiss();

        // Write a positive "premium granted" decision to the IN-MEMORY access
        // cache so the next access check is instant — no network round-trip.
        AccessService.markPremiumGranted();
        final months = selectedPlan['months'] as int;
        final expiry = DateTime.now().add(Duration(days: 30 * months));
        // markPremium() does THREE things (the "User-Specific Local Cache"
        // strategy):
        //   1. Updates the in-memory _user model → UI flips instantly.
        //   2. Writes isPremium_${userId}=true to SharedPreferences → survives
        //      app restart, prevents the "Locked" flash on next launch while
        //      the backend webhook grants the entitlement in Neon DB.
        //   3. Persists to Firestore (fire-and-forget) → backup mirror.
        // The cache key is USER-SPECIFIC, so a different user logging into
        // this device never inherits this premium. On the next app launch,
        // loadUserData() fetches the real-time status from Neon DB and
        // overwrites the cache (source of truth).
        auth.markPremium(
          expiry: expiry,
          planId: selectedPlan['planId'] as String,
        );
        // Note: we intentionally do NOT call auth.loadUserData() here.
        // loadUserData() hits Firestore (which doesn't store Prisma
        // subscription info) and triggers a loading state. The optimistic
        // markPremium above is sufficient for the UI.
        if (!mounted) return;
        // Show a PROMINENT success dialog (not a subtle snackbar). The user
        // taps "Done" to return. This fixes "payment er por kichui hoi na" —
        // the user now gets clear, unmissable feedback everywhere they pay.
        PaymentSuccessDialog.show(
          context,
          itemName: selectedPlan['name'] as String,
          amount: selectedPlan['price'] as int,
          actionLabel: 'Done',
          paymentId: response.paymentId,
        ).then((_) {
          if (!mounted) return;
          Navigator.pop(context);
        });
      },
      onError: (response) {
        progress.dismiss();
        // If the user explicitly cancelled, don't show a scary "Payment
        // failed" message — they already know.
        if (cancelled) return;
        if (!mounted) return;
        // Issue #30: add Retry + Contact Support actions to the failure
        // SnackBar so the user has an actionable next step instead of just
        // a generic "Payment failed" message. Retry re-triggers the
        // payment flow; Contact Support navigates to HelpSupportScreen.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'payment_failed_retry_msg')),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: tr(context, 'retry'),
              textColor: Colors.white,
              onPressed: _startPayment,
            ),
          ),
        );
        // Show a second, shorter-lived SnackBar with the Contact Support
        // action so both actions are reachable (a single SnackBar only
        // supports one SnackBarAction cleanly). Using a follow-up SnackBar
        // is the simplest pattern that doesn't require a custom widget.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr(context, 'test_paymentFailedPrefix')} '
                '${response.message ?? tr(context, 'test_paymentFailedGeneric')}'),
            backgroundColor: AppTheme.errorColor.withOpacity(0.85),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: tr(context, 'contact_support'),
              textColor: Colors.white,
              onPressed: () {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HelpSupportScreen()),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
