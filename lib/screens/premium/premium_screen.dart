// =============================================================================
// ExamVault - Premium/Payment Screen (Razorpay)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/razorpay_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlanIndex = 1; // Default: Quarterly (popular)

  @override
  Widget build(BuildContext context) {
    final plans = [
      {
        'name': 'Monthly',
        'price': AppConfig.premiumMonthlyPrice,
        'duration': '1 Month',
        'planId': AppConfig.monthlyPlanId,
        'features': ['All Premium Tests', 'Detailed Solutions', 'Ad-Free'],
      },
      {
        'name': 'Quarterly',
        'price': AppConfig.premiumQuarterlyPrice,
        'duration': '3 Months',
        'planId': AppConfig.quarterlyPlanId,
        'features': ['All Premium Tests', 'Detailed Solutions', 'Ad-Free', 'Priority Support'],
        'isPopular': true,
      },
      {
        'name': 'Yearly',
        'price': AppConfig.premiumYearlyPrice,
        'duration': '12 Months',
        'planId': AppConfig.yearlyPlanId,
        'features': ['All Premium Tests', 'Detailed Solutions', 'Ad-Free', 'Priority Support', 'AI Insights'],
        'discount': 'Save 33%',
      },
    ];

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
                    const Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
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
            ...List.generate(plans.length, (index) {
              final plan = plans[index];
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
                'Subscribe for ₹${plans[_selectedPlanIndex]['price']}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
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
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
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
                            plan['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isPopular) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    const Icon(Icons.check, size: 14, color: AppTheme.successColor),
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

    final plans = [
      {'name': 'Monthly', 'price': AppConfig.premiumMonthlyPrice, 'planId': AppConfig.monthlyPlanId, 'months': 1},
      {'name': 'Quarterly', 'price': AppConfig.premiumQuarterlyPrice, 'planId': AppConfig.quarterlyPlanId, 'months': 3},
      {'name': 'Yearly', 'price': AppConfig.premiumYearlyPrice, 'planId': AppConfig.yearlyPlanId, 'months': 12},
    ];

    final selectedPlan = plans[_selectedPlanIndex];

    RazorpayService.startPayment(
      userId: auth.user!.id,
      userName: auth.user!.name,
      userEmail: auth.user!.email ?? 'user@examvault.com',
      userPhone: auth.user?.phoneNumber ?? '9999999999',
      amount: selectedPlan['price'] as int,
      planId: selectedPlan['planId'] as String,
      planName: selectedPlan['name'] as String,
      durationMonths: selectedPlan['months'] as int,
      onSuccess: (response) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Premium activated!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        auth.loadUserData();
        Navigator.pop(context);
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
}
