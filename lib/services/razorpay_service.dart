// =============================================================================
// ExamVault - Razorpay Payment Service
// Subscription payments via Razorpay
// =============================================================================

import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';
import '../models/payment_model.dart';
import 'firebase_service.dart';

class RazorpayService {
  RazorpayService._();

  static late Razorpay _razorpay;

  static void initialize() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  // ==================== START PAYMENT ====================
  static Future<void> startPayment({
    required String userId,
    required String userName,
    required String userEmail,
    required String userPhone,
    required int amount, // in INR (will be converted to paise)
    required String planId,
    required String planName,
    required int durationMonths,
    required void Function(PaymentSuccessResponse response) onSuccess,
    required void Function(PaymentFailureResponse response) onError,
  }) async {
    // Create payment record in Firestore
    final paymentRecord = PaymentModel(
      id: '',
      userId: userId,
      razorpayOrderId: '',
      amount: amount * 100, // convert to paise
      currency: 'INR',
      status: PaymentStatus.created,
      planId: planId,
      planName: planName,
      durationMonths: durationMonths,
      createdAt: DateTime.now(),
    );

    final docRef = await FirebaseService.paymentsRef.add(paymentRecord.toFirestore());
    final paymentId = docRef.id;

    // Setup callbacks
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      _handlePaymentSuccessWithRecord(
        response,
        paymentId: paymentId,
        userId: userId,
        planName: planName,
        durationMonths: durationMonths,
      );
      onSuccess(response);
    });

    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      _handlePaymentErrorWithRecord(response, paymentId: paymentId);
      onError(response);
    });

    // Start Razorpay checkout
    final options = {
      'key': AppConfig.razorpayKeyId,
      'amount': amount * 100, // in paise
      'name': AppConfig.appName,
      'description': planName,
      'prefill': {
        'name': userName,
        'email': userEmail,
        'contact': userPhone,
      },
      'theme': {
        'color': '#1565C0',
      },
      'currency': 'INR',
      'timeout': 300, // 5 minutes
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      await _updatePaymentStatus(
        paymentId,
        PaymentStatus.failed,
        rawResponse: {'error': e.toString()},
      );
      rethrow;
    }
  }

  // ==================== PAYMENT SUCCESS HANDLER ====================
  static void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // Default handler - overridden in startPayment
  }

  static Future<void> _handlePaymentSuccessWithRecord(
    PaymentSuccessResponse response, {
    required String paymentId,
    required String userId,
    required String planName,
    required int durationMonths,
  }) async {
    await _updatePaymentStatus(
      paymentId,
      PaymentStatus.captured,
      razorpayPaymentId: response.paymentId,
      razorpayOrderId: response.orderId,
      razorpaySignature: response.signature,
      rawResponse: {
        'paymentId': response.paymentId,
        'orderId': response.orderId,
        'signature': response.signature,
      },
    );

    // Update user subscription
    final now = DateTime.now();
    final expiry = DateTime(now.year, now.month + durationMonths, now.day);

    await FirebaseService.usersRef.doc(userId).update({
      'subscriptionStatus': 'premium',
      'subscriptionExpiry': Timestamp.fromDate(expiry),
      'subscriptionPlanId': planName,
      'updatedAt': Timestamp.fromDate(now),
    });
  }

  // ==================== PAYMENT ERROR HANDLER ====================
  static void _handlePaymentError(PaymentFailureResponse response) {
    // Default handler - overridden in startPayment
  }

  static Future<void> _handlePaymentErrorWithRecord(
    PaymentFailureResponse response, {
    required String paymentId,
  }) async {
    await _updatePaymentStatus(
      paymentId,
      PaymentStatus.failed,
      rawResponse: {
        'code': response.code,
        'message': response.message,
        'error': response.error,
      },
    );
  }

  // ==================== EXTERNAL WALLET HANDLER ====================
  static void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet payments
  }

  // ==================== START TEST PURCHASE PAYMENT ====================
  /// Pay-per-test purchase. Charges the user the test's price and, on success,
  /// adds the testId to the user's `purchasedTests` list in Firestore so they
  /// can attempt the test any time. Premium users bypass this entirely.
  static Future<void> startTestPurchase({
    required String userId,
    required String userName,
    required String userEmail,
    required String userPhone,
    required String testId,
    required String testTitle,
    required int amount, // in INR
    required void Function(PaymentSuccessResponse response) onSuccess,
    required void Function(PaymentFailureResponse response) onError,
  }) async {
    // Create payment record
    final paymentRecord = PaymentModel(
      id: '',
      userId: userId,
      razorpayOrderId: '',
      amount: amount * 100, // paise
      currency: 'INR',
      status: PaymentStatus.created,
      planId: 'test_purchase_$testId',
      planName: testTitle,
      durationMonths: 0,
      createdAt: DateTime.now(),
    );

    final docRef =
        await FirebaseService.paymentsRef.add(paymentRecord.toFirestore());
    final paymentId = docRef.id;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse response) {
      _handleTestPurchaseSuccess(
        response,
        paymentId: paymentId,
        userId: userId,
        testId: testId,
      );
      onSuccess(response);
    });

    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse response) {
      _handlePaymentErrorWithRecord(response, paymentId: paymentId);
      onError(response);
    });

    final options = {
      'key': AppConfig.razorpayKeyId,
      'amount': amount * 100,
      'name': AppConfig.appName,
      'description': 'Test: $testTitle',
      'prefill': {
        'name': userName,
        'email': userEmail,
        'contact': userPhone,
      },
      'theme': {'color': '#1565C0'},
      'currency': 'INR',
      'timeout': 300,
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      await _updatePaymentStatus(
        paymentId,
        PaymentStatus.failed,
        rawResponse: {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// On successful test purchase, mark the payment captured AND add the testId
  /// to the user's purchasedTests list (using FieldValue.arrayUnion so it's
  /// idempotent — buying the same test twice doesn't create duplicates).
  static Future<void> _handleTestPurchaseSuccess(
    PaymentSuccessResponse response, {
    required String paymentId,
    required String userId,
    required String testId,
  }) async {
    await _updatePaymentStatus(
      paymentId,
      PaymentStatus.captured,
      razorpayPaymentId: response.paymentId,
      razorpayOrderId: response.orderId,
      razorpaySignature: response.signature,
      rawResponse: {
        'paymentId': response.paymentId,
        'orderId': response.orderId,
        'signature': response.signature,
        'type': 'test_purchase',
        'testId': testId,
      },
    );

    // Add the test to the user's purchasedTests list.
    await FirebaseService.usersRef.doc(userId).set({
      'purchasedTests': FieldValue.arrayUnion([testId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ==================== UPDATE PAYMENT STATUS ====================
  static Future<void> _updatePaymentStatus(
    String paymentId,
    PaymentStatus status, {
    String? razorpayPaymentId,
    String? razorpayOrderId,
    String? razorpaySignature,
    Map<String, dynamic>? rawResponse,
  }) async {
    final updates = <String, dynamic>{
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (razorpayPaymentId != null) updates['razorpayPaymentId'] = razorpayPaymentId;
    if (razorpayOrderId != null) updates['razorpayOrderId'] = razorpayOrderId;
    if (razorpaySignature != null) updates['razorpaySignature'] = razorpaySignature;
    if (status == PaymentStatus.captured || status == PaymentStatus.failed) {
      updates['completedAt'] = FieldValue.serverTimestamp();
    }
    if (rawResponse != null) updates['rawResponse'] = rawResponse;

    await FirebaseService.paymentsRef.doc(paymentId).update(updates);
  }

  // ==================== CLEANUP ====================
  static void clear() {
    _razorpay.clear();
  }
}
