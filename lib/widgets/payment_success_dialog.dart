// =============================================================================
// ExamVault - Payment Success Dialog
// =============================================================================
// A prominent, professional success dialog shown after a successful payment.
// Shows a checkmark animation, "Payment Successful!" message, the unlocked
// item's name, and an action button (Open Test / Open PDF / etc.).
//
// This replaces the old subtle SnackBar that users missed ("payment er por
// kichui hoi na" — nothing happens after payment). The dialog is modal and
// requires the user to tap "Open" — guaranteeing they see the confirmation.
// =============================================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PaymentSuccessDialog {
  /// Shows the success dialog and waits for the user to tap the action button.
  /// Returns true if the user tapped the action button, false if dismissed.
  ///
  /// [itemName] — the name of the unlocked item (e.g. test title).
  /// [amount] — the amount paid in rupees (for display).
  /// [actionLabel] — the label for the action button (e.g. "Open Test").
  /// [paymentId] — optional Razorpay payment ID for reference.
  static Future<bool> show(
    BuildContext context, {
    required String itemName,
    required int amount,
    String actionLabel = 'Open Test',
    String? paymentId,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated checkmark in a green circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Payment Successful!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.successColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹$amount paid successfully',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_open,
                              size: 18, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              itemName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.verified,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 8),
                          Text(
                            'Unlocked & ready to access',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (paymentId != null && paymentId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Payment ID: $paymentId',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Action button — full width, prominent
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(
                      'Later',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }
}
