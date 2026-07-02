// =============================================================================
// ExamVault - Premium/Payment Screen (Razorpay)
// Premium plans are admin-controllable: this screen fetches them from the
// `premium_plans` Firestore collection. If there are no plans in Firestore,
// the screen shows an empty state — it NEVER shows fake/hardcoded plans.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/access_service.dart';
import '../../services/razorpay_service.dart';
import '../../services/firestore_service.dart';
import '../../models/premium_plan_model.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlanIndex = 1; // Default: Quarterly (popular)
  List<Map<String, dynamic>> _plans = const [];
  bool _isLoadingPlans = true;

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

  @override
  Widget build(BuildContext context) {
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
              // Subscribe Button
              ElevatedButton(
                onPressed: _startPayment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Subscribe for ₹${_plans[_selectedPlanIndex]['price']}',
                  style: const TextStyle(fontSize: 16),
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
    if (auth.user == null) return;
    if (_plans.isEmpty) return;

    final selectedPlan = _plans[_selectedPlanIndex];

    // Track loading dialogs on screen so we can dismiss exactly one in each
    // exit path.
    int dialogsOnScreen = 0;
    // If the user pressed Cancel, ignore all subsequent callbacks.
    bool cancelled = false;

    void showLoadingDialog(String message, {bool cancellable = false}) {
      if (!mounted || cancelled) return;
      dialogsOnScreen++;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        builder: (_) => PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 20),
                      Flexible(
                        child: Text(
                          message,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  if (cancellable) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          cancelled = true;
                          Navigator.of(context, rootNavigator: true).pop();
                          dialogsOnScreen--;
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    void dismissLoadingDialog() {
      if (cancelled) return;
      if (dialogsOnScreen > 0 && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogsOnScreen--;
      }
    }

    RazorpayService.startPayment(
      userId: auth.user!.id,
      userName: auth.user!.name,
      userEmail: auth.user!.email ?? 'user@examvault.com',
      userPhone: auth.user?.phoneNumber ?? '9999999999',
      amount: selectedPlan['price'] as int,
      planId: selectedPlan['planId'] as String,
      planName: selectedPlan['name'] as String,
      durationMonths: selectedPlan['months'] as int,
      planTier: selectedPlan['name'] as String,
      onPreparing: () {
        showLoadingDialog('Preparing payment...', cancellable: true);
      },
      onCheckoutOpened: () {
        dismissLoadingDialog();
      },
      onVerifying: () {
        dismissLoadingDialog();
        showLoadingDialog('Verifying payment...', cancellable: false);
      },
      onSuccess: (response) {
        if (cancelled) return;
        // Dismiss the "Verifying" dialog.
        dismissLoadingDialog();

        // Write a positive "premium granted" decision to the cache so the
        // next access check is instant — no network round-trip. This is the
        // key fix for the post-payment loading delay.
        AccessService.markPremiumGranted();
        final months = selectedPlan['months'] as int;
        final expiry = DateTime.now().add(Duration(days: 30 * months));
        auth.markPremium(
          expiry: expiry,
          planId: selectedPlan['planId'] as String,
        );
        // Note: we intentionally do NOT call auth.loadUserData() here.
        // loadUserData() hits Firestore (which doesn't store Prisma
        // subscription info) and triggers a loading state. The optimistic
        // markPremium above is sufficient for the UI.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Premium activated!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context);
      },
      onError: (response) {
        if (cancelled) return;
        dismissLoadingDialog();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${response.message ?? 'Please try again.'}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      },
    );
  }
}
