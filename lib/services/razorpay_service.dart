// =============================================================================
// ExamVault - Razorpay Payment Service (SERVER-SIDE-VERIFIED FLOW)
// =============================================================================
// v1.23+ — NO LONGER writes payment success to Firestore from the client.
// The flow is now:
//   1. createOrder()  → backend creates a Razorpay order + Prisma Order row
//   2. open Razorpay checkout WITH that order_id (mandatory for signature
//      verification to work)
//   3. On EVENT_PAYMENT_SUCCESS → verifyPayment() with the signature; only
//      call onSuccess if the backend returns { success: true, granted: true }
//   4. On EVENT_PAYMENT_ERROR → call onError with the Razorpay failure
//
// The old `payments` Firestore collection and PaymentModel are kept for
// backward-compat with historical records; NEW payments are recorded by the
// backend in Prisma, not here.
// =============================================================================

import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import 'payment_api_service.dart';

class RazorpayService {
  RazorpayService._();

  // Nullable instead of late — if initialize() fails (caught in main.dart),
  // _razorpay stays null and payment methods bail early instead of throwing
  // LateInitializationError.
  static Razorpay? _razorpay;

  static void initialize() {
    _razorpay = Razorpay();
    // Register default no-op handlers. Each start*() method re-registers
    // success/error with closures that capture the active order's Prisma id
    // so it can be passed to /verify.
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _defaultSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _defaultError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _defaultWallet);
  }

  static void _defaultSuccess(PaymentSuccessResponse _) {}
  static void _defaultError(PaymentFailureResponse _) {}
  static void _defaultWallet(ExternalWalletResponse _) {}

  // ==================== START SUBSCRIPTION PAYMENT ====================
  /// Premium subscription payment. Creates a server-side order, opens Razorpay
  /// checkout, verifies the signature, and only calls [onSuccess] if the
  /// backend confirms the entitlement was granted.
  static Future<void> startPayment({
    required String userId,
    required String userName,
    required String userEmail,
    required String userPhone,
    required int amount, // in INR (whole rupees)
    required String planId,
    required String planName,
    required int durationMonths,
    String? planTier,
    required void Function(PaymentSuccessResponse response) onSuccess,
    required void Function(PaymentFailureResponse response) onError,
  }) async {
    if (_razorpay == null) {
      throw Exception(
          'Payment service not available. Please restart the app.');
    }

    final idempotencyKey = const Uuid().v4();

    // 1) Create the order on the backend.
    Map<String, dynamic> order;
    try {
      order = await PaymentApiService.createOrder(
        productType: 'PREMIUM_SUBSCRIPTION',
        productId: planId,
        productName: planName,
        amountRupees: amount.toDouble(),
        idempotencyKey: idempotencyKey,
        meta: {
          'planId': planId,
          'planName': planName,
          if (planTier != null) 'planTier': planTier,
          'durationMonths': durationMonths,
        },
      );
    } on PaymentApiException catch (e) {
      onError(PaymentFailureResponse(0, e.message, null));
      return;
    } catch (e) {
      onError(PaymentFailureResponse(
          0, 'Could not start payment. Please try again.', null));
      return;
    }

    if (!_openCheckout(
      order: order,
      fallbackAmountPaise: amount * 100,
      description: planName,
      prefillName: userName,
      prefillEmail: userEmail,
      prefillPhone: userPhone,
      onSuccess: onSuccess,
      onError: onError,
    )) {
      return;
    }
  }

  // ==================== START TEST PURCHASE ====================
  /// Pay-per-test purchase. Charges the user the test's price and, on
  /// server-verified success, the backend adds the testId to the user's
  /// entitlements. [onSuccess] is only called when the backend confirms.
  static Future<void> startTestPurchase({
    required String userId,
    required String userName,
    required String userEmail,
    required String userPhone,
    required String testId,
    required String testTitle,
    required int amount, // in INR
    String? subjectId,
    String? categoryId,
    required void Function(PaymentSuccessResponse response) onSuccess,
    required void Function(PaymentFailureResponse response) onError,
  }) async {
    if (_razorpay == null) {
      throw Exception(
          'Payment service not available. Please restart the app.');
    }

    final idempotencyKey = const Uuid().v4();

    Map<String, dynamic> order;
    try {
      order = await PaymentApiService.createOrder(
        productType: 'TEST_PURCHASE',
        productId: testId,
        productName: testTitle,
        amountRupees: amount.toDouble(),
        idempotencyKey: idempotencyKey,
        meta: {
          'testId': testId,
          'testTitle': testTitle,
          if (subjectId != null) 'subjectId': subjectId,
          if (categoryId != null) 'categoryId': categoryId,
        },
      );
    } on PaymentApiException catch (e) {
      onError(PaymentFailureResponse(0, e.message, null));
      return;
    } catch (e) {
      onError(PaymentFailureResponse(
          0, 'Could not start payment. Please try again.', null));
      return;
    }

    if (!_openCheckout(
      order: order,
      fallbackAmountPaise: amount * 100,
      description: 'Test: $testTitle',
      prefillName: userName,
      prefillEmail: userEmail,
      prefillPhone: userPhone,
      onSuccess: onSuccess,
      onError: onError,
    )) {
      return;
    }
  }

  // ==================== START SUBJECT PACK PURCHASE ====================
  /// Unlock all tests in a subject. [amount] is the pack price in INR.
  static Future<void> startSubjectPackPurchase({
    required String userId,
    required String userName,
    required String userEmail,
    required String userPhone,
    required String subjectId,
    required String subjectName,
    required int amount, // in INR
    String? categoryId,
    required void Function(PaymentSuccessResponse response) onSuccess,
    required void Function(PaymentFailureResponse response) onError,
  }) async {
    if (_razorpay == null) {
      throw Exception(
          'Payment service not available. Please restart the app.');
    }

    final idempotencyKey = const Uuid().v4();

    Map<String, dynamic> order;
    try {
      order = await PaymentApiService.createOrder(
        productType: 'SUBJECT_PACK',
        productId: subjectId,
        productName: 'Subject Pack: $subjectName',
        amountRupees: amount.toDouble(),
        idempotencyKey: idempotencyKey,
        meta: {
          'subjectId': subjectId,
          'subjectName': subjectName,
          if (categoryId != null) 'categoryId': categoryId,
        },
      );
    } on PaymentApiException catch (e) {
      onError(PaymentFailureResponse(0, e.message, null));
      return;
    } catch (e) {
      onError(PaymentFailureResponse(
          0, 'Could not start payment. Please try again.', null));
      return;
    }

    if (!_openCheckout(
      order: order,
      fallbackAmountPaise: amount * 100,
      description: 'Subject Pack: $subjectName',
      prefillName: userName,
      prefillEmail: userEmail,
      prefillPhone: userPhone,
      onSuccess: onSuccess,
      onError: onError,
    )) {
      return;
    }
  }

  // ==================== START EXAM PACK PURCHASE ====================
  /// Unlock all subjects/tests in a category (exam pack). [amount] is the
  /// pack price in INR.
  static Future<void> startExamPackPurchase({
    required String userId,
    required String userName,
    required String userEmail,
    required String userPhone,
    required String categoryId,
    required String categoryName,
    required int amount, // in INR
    required void Function(PaymentSuccessResponse response) onSuccess,
    required void Function(PaymentFailureResponse response) onError,
  }) async {
    if (_razorpay == null) {
      throw Exception(
          'Payment service not available. Please restart the app.');
    }

    final idempotencyKey = const Uuid().v4();

    Map<String, dynamic> order;
    try {
      order = await PaymentApiService.createOrder(
        productType: 'EXAM_PACK',
        productId: categoryId,
        productName: 'Exam Pack: $categoryName',
        amountRupees: amount.toDouble(),
        idempotencyKey: idempotencyKey,
        meta: {
          'categoryId': categoryId,
          'categoryName': categoryName,
        },
      );
    } on PaymentApiException catch (e) {
      onError(PaymentFailureResponse(0, e.message, null));
      return;
    } catch (e) {
      onError(PaymentFailureResponse(
          0, 'Could not start payment. Please try again.', null));
      return;
    }

    if (!_openCheckout(
      order: order,
      fallbackAmountPaise: amount * 100,
      description: 'Exam Pack: $categoryName',
      prefillName: userName,
      prefillEmail: userEmail,
      prefillPhone: userPhone,
      onSuccess: onSuccess,
      onError: onError,
    )) {
      return;
    }
  }

  // ==================== OPEN CHECKOUT (shared) ====================
  /// Shared helper that validates the create-order response, wires the
  /// success/error handlers to a /verify call, and opens Razorpay checkout.
  /// Returns true if checkout was opened; false if an error was already
  /// dispatched via [onError] (so the caller knows not to do anything else).
  static bool _openCheckout({
    required Map<String, dynamic> order,
    required int fallbackAmountPaise,
    required String description,
    required String prefillName,
    required String prefillEmail,
    required String prefillPhone,
    required void Function(PaymentSuccessResponse) onSuccess,
    required void Function(PaymentFailureResponse) onError,
  }) {
    final orderId = (order['orderId'] ?? '').toString();
    final razorpayOrderId = (order['razorpayOrderId'] ?? '').toString();
    final keyId = (order['keyId'] ?? AppConfig.razorpayKeyId).toString();
    final amountPaise = order['amount'] is int
        ? order['amount'] as int
        : (order['amount'] is num
            ? (order['amount'] as num).toInt()
            : fallbackAmountPaise);

    if (orderId.isEmpty || razorpayOrderId.isEmpty) {
      onError(PaymentFailureResponse(
          0, 'Server returned an invalid order. Please try again.', null));
      return false;
    }

    // Re-register handlers with closures that capture the Prisma orderId so
    // we can call /verify with it on success.
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS,
        (PaymentSuccessResponse response) async {
      await _verifyAndDispatch(
        response: response,
        orderId: orderId,
        onSuccess: onSuccess,
        onError: onError,
      );
    });
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR,
        (PaymentFailureResponse response) {
      onError(response);
    });

    final options = <String, dynamic>{
      'key': keyId,
      'order_id': razorpayOrderId, // CRITICAL for server-side verification
      'amount': amountPaise,
      'name': AppConfig.appName,
      'description': description,
      'prefill': {
        'name': prefillName,
        'email': prefillEmail,
        'contact': prefillPhone,
      },
      'theme': {'color': '#1565C0'},
      'currency': 'INR',
      'timeout': 300, // 5 minutes
    };

    try {
      _razorpay!.open(options);
      return true;
    } catch (e) {
      onError(PaymentFailureResponse(
          0, 'Could not open payment screen. Please try again.', null));
      return false;
    }
  }

  // ==================== VERIFY + DISPATCH ====================
  /// Calls /api/payments/verify with the Razorpay signature. Only invokes
  /// [onSuccess] if the backend returns { success: true, granted: true }.
  /// On any failure (including signature mismatch), invokes [onError] with a
  /// synthetic PaymentFailureResponse carrying the server's message.
  static Future<void> _verifyAndDispatch({
    required PaymentSuccessResponse response,
    required String orderId,
    required void Function(PaymentSuccessResponse) onSuccess,
    required void Function(PaymentFailureResponse) onError,
  }) async {
    try {
      final result = await PaymentApiService.verifyPayment(
        orderId: orderId,
        razorpayPaymentId: response.paymentId ?? '',
        razorpayOrderId: response.orderId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      final ok = result['success'] == true && result['granted'] == true;
      if (ok) {
        onSuccess(response);
      } else {
        final msg = (result['message'] ??
                'Payment could not be verified. If money was deducted, it will be refunded within 5-7 business days.')
            .toString();
        onError(PaymentFailureResponse(0, msg, null));
      }
    } on PaymentApiException catch (e) {
      onError(PaymentFailureResponse(0, e.message, null));
    } catch (e) {
      onError(PaymentFailureResponse(
        0,
        'Payment verification failed. If money was deducted, it will be refunded within 5-7 business days.',
        null,
      ));
    }
  }

  // ==================== CLEANUP ====================
  static void clear() {
    _razorpay?.clear();
  }
}
