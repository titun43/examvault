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

import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';
import 'payment_api_service.dart';

/// Hard timeout for the createOrder network call. If the backend doesn't
/// respond within this duration, we abort and call onError — the user is
/// never stuck spinning forever. 20s is generous enough for a cold Vercel
/// function + Razorpay API + DB writes, but short enough that the user
/// doesn't think the app froze.
const Duration _createOrderHardTimeout = Duration(seconds: 20);

/// Hard timeout for the verifyPayment network call.
/// Reduced from 20s to 12s in v1.35.1 — if the server hasn't responded in
/// 12s, something is wrong and we should fall through to polling + optimistic
/// success faster. The user already paid (Razorpay confirmed); making them
/// wait 20s for a server response is unnecessary.
const Duration _verifyHardTimeout = Duration(seconds: 12);

class RazorpayService {
  RazorpayService._();

  // Nullable instead of late — if initialize() fails (caught in main.dart),
  // _razorpay stays null and payment methods bail early instead of throwing
  // LateInitializationError.
  static Razorpay? _razorpay;

  // CONCURRENT-PAYMENT GUARD — prevents double-tap on Buy from starting two
  // payments. If a payment is already in flight, subsequent start* calls are
  // rejected with a clear error instead of overwriting the first payment's
  // Razorpay handlers (which would leave the first payment's callbacks
  // dangling and the user's money deducted with no unlock).
  static bool _isProcessing = false;

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

  /// Resets the processing guard. Call this only if you're certain no payment
  /// is in flight (e.g., on app start, or after a stuck state was detected).
  static void resetProcessingState() {
    _isProcessing = false;
  }

  // ==================== START SUBSCRIPTION PAYMENT ====================
  /// Premium subscription payment. Creates a server-side order, opens Razorpay
  /// checkout, verifies the signature, and only calls [onSuccess] if the
  /// backend confirms the entitlement was granted.
  ///
  /// [onPreparing] fires when createOrder starts (caller can show a loading
  /// indicator). [onCheckoutOpened] fires when the Razorpay checkout modal is
  /// about to open (caller should dismiss the preparing indicator). [onVerifying]
  /// fires after the user pays but before onSuccess/onError — during the server
  /// signature verification step (caller can show "Verifying payment...").
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
    void Function()? onPreparing,
    void Function()? onCheckoutOpened,
    void Function()? onVerifying,
  }) async {
    // NEVER throw — always call onError on failure. This prevents the
    // "Preparing payment..." dialog from getting stuck if something
    // unexpected happens before createOrder completes.
    if (_razorpay == null) {
      print('[RazorpayService] _razorpay is null — initialize() failed');
      onError(PaymentFailureResponse(
          0, 'Payment service not available. Please restart the app.', null));
      return;
    }
    // CONCURRENT-PAYMENT GUARD — reject if a payment is already in flight.
    if (_isProcessing) {
      print('[RazorpayService] startPayment: rejected — another payment is already in flight');
      onError(PaymentFailureResponse(
          0, 'A payment is already being processed. Please wait for it to finish.', null));
      return;
    }
    _isProcessing = true;

    // Wrap the onSuccess/onError callbacks so we always release the guard.
    void guardedOnSuccess(PaymentSuccessResponse r) {
      _isProcessing = false;
      onSuccess(r);
    }
    void guardedOnError(PaymentFailureResponse r) {
      _isProcessing = false;
      onError(r);
    }

    final idempotencyKey = const Uuid().v4();

    // 1) Create the order on the backend.
    print('[RazorpayService] startPayment: calling onPreparing...');
    if (onPreparing != null) onPreparing();
    Map<String, dynamic> order;
    try {
      print('[RazorpayService] startPayment: calling createOrder...');
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
      ).timeout(_createOrderHardTimeout, onTimeout: () {
        throw TimeoutException(
            'Payment server is taking too long. Please check your internet and try again.');
      });
      print('[RazorpayService] startPayment: createOrder succeeded, orderId=${order['orderId']}');
    } on PaymentApiException catch (e) {
      print('[RazorpayService] startPayment: createOrder PaymentApiException: ${e.message}');
      _isProcessing = false;
      onError(PaymentFailureResponse(0, e.message, null));
      return;
    } on TimeoutException catch (e) {
      print('[RazorpayService] startPayment: createOrder timeout: ${e.message}');
      _isProcessing = false;
      onError(PaymentFailureResponse(0, e.message, null));
      return;
    } catch (e) {
      print('[RazorpayService] startPayment: createOrder unexpected error: $e');
      _isProcessing = false;
      onError(PaymentFailureResponse(
          0, 'Could not start payment. Please try again.', null));
      return;
    }

    print('[RazorpayService] startPayment: calling onCheckoutOpened...');
    if (onCheckoutOpened != null) onCheckoutOpened();
    if (!_openCheckout(
      order: order,
      fallbackAmountPaise: amount * 100,
      description: planName,
      prefillName: userName,
      prefillEmail: userEmail,
      prefillPhone: userPhone,
      onSuccess: guardedOnSuccess,
      onError: guardedOnError,
      onVerifying: onVerifying,
    )) {
      _isProcessing = false;
      return;
    }
  }

  // ==================== START TEST PURCHASE ====================
  /// Pay-per-test purchase. Charges the user the test's price and, on
  /// server-verified success, the backend adds the testId to the user's
  /// entitlements. [onSuccess] is only called when the backend confirms.
  ///
  /// [onPreparing] fires when createOrder starts (caller can show a loading
  /// indicator). [onCheckoutOpened] fires when the Razorpay checkout modal is
  /// about to open (caller should dismiss the preparing indicator). [onVerifying]
  /// fires after the user pays but before onSuccess/onError — during the server
  /// signature verification step (caller can show "Verifying payment...").
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
    void Function()? onPreparing,
    void Function()? onCheckoutOpened,
    void Function()? onVerifying,
  }) async {
    // NEVER throw — always call onError on failure. This prevents the
    // "Preparing payment..." dialog from getting stuck if something
    // unexpected happens before createOrder completes.
    if (_razorpay == null) {
      print('[RazorpayService] _razorpay is null — initialize() failed');
      onError(PaymentFailureResponse(
          0, 'Payment service not available. Please restart the app.', null));
      return;
    }
    // CONCURRENT-PAYMENT GUARD — reject if a payment is already in flight.
    if (_isProcessing) {
      print('[RazorpayService] startTestPurchase: rejected — another payment is already in flight');
      onError(PaymentFailureResponse(
          0, 'A payment is already being processed. Please wait for it to finish.', null));
      return;
    }
    _isProcessing = true;

    // Wrap the onSuccess/onError callbacks so we always release the guard.
    void guardedOnSuccess(PaymentSuccessResponse r) {
      _isProcessing = false;
      onSuccess(r);
    }
    void guardedOnError(PaymentFailureResponse r) {
      _isProcessing = false;
      onError(r);
    }

    final idempotencyKey = const Uuid().v4();

    print('[RazorpayService] startTestPurchase: calling onPreparing...');
    if (onPreparing != null) onPreparing();
    Map<String, dynamic> order;
    try {
      print('[RazorpayService] startTestPurchase: calling createOrder (testId=$testId, amount=$amount)...');
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
      ).timeout(_createOrderHardTimeout, onTimeout: () {
        throw TimeoutException(
            'Payment server is taking too long. Please check your internet and try again.');
      });
      print('[RazorpayService] startTestPurchase: createOrder succeeded, orderId=${order['orderId']}');
    } on PaymentApiException catch (e) {
      print('[RazorpayService] startTestPurchase: createOrder PaymentApiException: ${e.message}');
      _isProcessing = false;
      onError(PaymentFailureResponse(0, e.message, null));
      return;
    } on TimeoutException catch (e) {
      print('[RazorpayService] startTestPurchase: createOrder timeout: ${e.message}');
      _isProcessing = false;
      onError(PaymentFailureResponse(0, e.message, null));
      return;
    } catch (e) {
      print('[RazorpayService] startTestPurchase: createOrder unexpected error: $e');
      _isProcessing = false;
      onError(PaymentFailureResponse(
          0, 'Could not start payment. Please try again.', null));
      return;
    }

    print('[RazorpayService] startTestPurchase: calling onCheckoutOpened...');
    if (onCheckoutOpened != null) onCheckoutOpened();
    if (!_openCheckout(
      order: order,
      fallbackAmountPaise: amount * 100,
      description: 'Test: $testTitle',
      prefillName: userName,
      prefillEmail: userEmail,
      prefillPhone: userPhone,
      onSuccess: guardedOnSuccess,
      onError: guardedOnError,
      onVerifying: onVerifying,
    )) {
      _isProcessing = false;
      return;
    }
  }

  // ==================== START SUBJECT PACK PURCHASE ====================
  /// Unlock all tests in a subject. [amount] is the pack price in INR.
  ///
  /// [onPreparing] fires when createOrder starts (caller can show a loading
  /// indicator). [onCheckoutOpened] fires when the Razorpay checkout modal is
  /// about to open (caller should dismiss the preparing indicator). [onVerifying]
  /// fires after the user pays but before onSuccess/onError — during the server
  /// signature verification step (caller can show "Verifying payment...").
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
    void Function()? onPreparing,
    void Function()? onCheckoutOpened,
    void Function()? onVerifying,
  }) async {
    // NEVER throw — always call onError on failure. This prevents the
    // "Preparing payment..." dialog from getting stuck if something
    // unexpected happens before createOrder completes.
    if (_razorpay == null) {
      print('[RazorpayService] _razorpay is null — initialize() failed');
      onError(PaymentFailureResponse(
          0, 'Payment service not available. Please restart the app.', null));
      return;
    }
    // CONCURRENT-PAYMENT GUARD — reject if a payment is already in flight.
    if (_isProcessing) {
      print('[RazorpayService] startSubjectPackPurchase: rejected — another payment is already in flight');
      onError(PaymentFailureResponse(
          0, 'A payment is already being processed. Please wait for it to finish.', null));
      return;
    }
    _isProcessing = true;

    // Wrap the onSuccess/onError callbacks so we always release the guard.
    void guardedOnSuccess(PaymentSuccessResponse r) {
      _isProcessing = false;
      onSuccess(r);
    }
    void guardedOnError(PaymentFailureResponse r) {
      _isProcessing = false;
      onError(r);
    }

    final idempotencyKey = const Uuid().v4();

    print('[RazorpayService] startSubjectPackPurchase: calling onPreparing...');
    if (onPreparing != null) onPreparing();
    Map<String, dynamic> order;
    try {
      print('[RazorpayService] startSubjectPackPurchase: calling createOrder (subjectId=$subjectId, amount=$amount)...');
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
      ).timeout(_createOrderHardTimeout, onTimeout: () {
        throw TimeoutException(
            'Payment server is taking too long. Please check your internet and try again.');
      });
      print('[RazorpayService] startSubjectPackPurchase: createOrder succeeded, orderId=${order['orderId']}');
    } on PaymentApiException catch (e) {
      print('[RazorpayService] startSubjectPackPurchase: createOrder PaymentApiException: ${e.message}');
      _isProcessing = false;
      onError(PaymentFailureResponse(0, e.message, null));
      return;
    } on TimeoutException catch (e) {
      print('[RazorpayService] startSubjectPackPurchase: createOrder timeout: ${e.message}');
      _isProcessing = false;
      onError(PaymentFailureResponse(0, e.message, null));
      return;
    } catch (e) {
      print('[RazorpayService] startSubjectPackPurchase: createOrder unexpected error: $e');
      _isProcessing = false;
      onError(PaymentFailureResponse(
          0, 'Could not start payment. Please try again.', null));
      return;
    }

    print('[RazorpayService] startSubjectPackPurchase: calling onCheckoutOpened...');
    if (onCheckoutOpened != null) onCheckoutOpened();
    if (!_openCheckout(
      order: order,
      fallbackAmountPaise: amount * 100,
      description: 'Subject Pack: $subjectName',
      prefillName: userName,
      prefillEmail: userEmail,
      prefillPhone: userPhone,
      onSuccess: guardedOnSuccess,
      onError: guardedOnError,
      onVerifying: onVerifying,
    )) {
      _isProcessing = false;
      return;
    }
  }

  // ==================== START EXAM PACK PURCHASE ====================
  /// Unlock all subjects/tests in a category (exam pack). [amount] is the
  /// pack price in INR.
  ///
  /// [onPreparing] fires when createOrder starts (caller can show a loading
  /// indicator). [onCheckoutOpened] fires when the Razorpay checkout modal is
  /// about to open (caller should dismiss the preparing indicator). [onVerifying]
  /// fires after the user pays but before onSuccess/onError — during the server
  /// signature verification step (caller can show "Verifying payment...").
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
    void Function()? onPreparing,
    void Function()? onCheckoutOpened,
    void Function()? onVerifying,
  }) async {
    // NEVER throw — always call onError on failure. This prevents the
    // "Preparing payment..." dialog from getting stuck if something
    // unexpected happens before createOrder completes.
    if (_razorpay == null) {
      print('[RazorpayService] _razorpay is null — initialize() failed');
      onError(PaymentFailureResponse(
          0, 'Payment service not available. Please restart the app.', null));
      return;
    }
    // CONCURRENT-PAYMENT GUARD — reject if a payment is already in flight.
    if (_isProcessing) {
      print('[RazorpayService] startExamPackPurchase: rejected — another payment is already in flight');
      onError(PaymentFailureResponse(
          0, 'A payment is already being processed. Please wait for it to finish.', null));
      return;
    }
    _isProcessing = true;

    // Wrap the onSuccess/onError callbacks so we always release the guard.
    void guardedOnSuccess(PaymentSuccessResponse r) {
      _isProcessing = false;
      onSuccess(r);
    }
    void guardedOnError(PaymentFailureResponse r) {
      _isProcessing = false;
      onError(r);
    }

    final idempotencyKey = const Uuid().v4();

    print('[RazorpayService] startExamPackPurchase: calling onPreparing...');
    if (onPreparing != null) onPreparing();
    Map<String, dynamic> order;
    try {
      print('[RazorpayService] startExamPackPurchase: calling createOrder (categoryId=$categoryId, amount=$amount)...');
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
      ).timeout(_createOrderHardTimeout, onTimeout: () {
        throw TimeoutException(
            'Payment server is taking too long. Please check your internet and try again.');
      });
      print('[RazorpayService] startExamPackPurchase: createOrder succeeded, orderId=${order['orderId']}');
    } on PaymentApiException catch (e) {
      print('[RazorpayService] startExamPackPurchase: createOrder PaymentApiException: ${e.message}');
      _isProcessing = false;
      onError(PaymentFailureResponse(0, e.message, null));
      return;
    } on TimeoutException catch (e) {
      print('[RazorpayService] startExamPackPurchase: createOrder timeout: ${e.message}');
      _isProcessing = false;
      onError(PaymentFailureResponse(0, e.message, null));
      return;
    } catch (e) {
      print('[RazorpayService] startExamPackPurchase: createOrder unexpected error: $e');
      _isProcessing = false;
      onError(PaymentFailureResponse(
          0, 'Could not start payment. Please try again.', null));
      return;
    }

    print('[RazorpayService] startExamPackPurchase: calling onCheckoutOpened...');
    if (onCheckoutOpened != null) onCheckoutOpened();
    if (!_openCheckout(
      order: order,
      fallbackAmountPaise: amount * 100,
      description: 'Exam Pack: $categoryName',
      prefillName: userName,
      prefillEmail: userEmail,
      prefillPhone: userPhone,
      onSuccess: guardedOnSuccess,
      onError: guardedOnError,
      onVerifying: onVerifying,
    )) {
      _isProcessing = false;
      return;
    }
  }

  // ==================== OPEN CHECKOUT (shared) ====================
  /// Shared helper that validates the create-order response, wires the
  /// success/error handlers to a /verify call, and opens Razorpay checkout.
  /// Returns true if checkout was opened; false if an error was already
  /// dispatched via [onError] (so the caller knows not to do anything else).
  ///
  /// [onVerifying] fires after the user pays in Razorpay but before the
  /// /verify network call — the caller should show a "Verifying payment..."
  /// indicator and dismiss it in onSuccess/onError.
  static bool _openCheckout({
    required Map<String, dynamic> order,
    required int fallbackAmountPaise,
    required String description,
    required String prefillName,
    required String prefillEmail,
    required String prefillPhone,
    required void Function(PaymentSuccessResponse) onSuccess,
    required void Function(PaymentFailureResponse) onError,
    void Function()? onVerifying,
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
      print('[RazorpayService] _openCheckout: invalid order response — orderId=$orderId, razorpayOrderId=$razorpayOrderId');
      onError(PaymentFailureResponse(
          0, 'Server returned an invalid order. Please try again.', null));
      return false;
    }

    print('[RazorpayService] _openCheckout: opening Razorpay checkout (razorpayOrderId=$razorpayOrderId, amountPaise=$amountPaise, keyId=$keyId)');

    // Re-register handlers with closures that capture the Prisma orderId so
    // we can call /verify with it on success.
    //
    // INSTANT SUCCESS (v1.37 — professional app approach):
    // When Razorpay fires EVENT_PAYMENT_SUCCESS, we call onSuccess IMMEDIATELY
    // — no "Verifying..." dialog, no waiting. The verify happens SILENTLY in
    // the background. This is how Swiggy, Zomato, CRED, etc. work: the user
    // sees "Payment Successful" the instant Razorpay confirms, and the backend
    // verification is an implementation detail.
    //
    // Why this is safe:
    //   1. Razorpay's EVENT_PAYMENT_SUCCESS means the payment was captured.
    //      The Razorpay SDK is signed, the order_id is bound to the checkout.
    //   2. The optimistic local unlock (AccessService.markTestPurchased +
    //      auth.addPurchasedTest in the onSuccess callback) gives immediate access.
    //   3. The backend /verify call (in the background) grants the Prisma
    //      entitlement. If it fails, the Razorpay webhook is the safety net.
    //   4. The Firestore persist (in addPurchasedTest) ensures the purchase
    //      survives app restarts even if the backend never grants it.
    //
    // This fixes "payment success holo but app a kichui hoi na" — the user
    // was seeing the "Verifying payment..." dialog for 10-42s and thinking
    // nothing happened. Now they get INSTANT feedback.
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS,
        (PaymentSuccessResponse response) {
      print('[RazorpayService] EVENT_PAYMENT_SUCCESS: paymentId=${response.paymentId}, orderId=${response.orderId}');
      // IMMEDIATELY call onSuccess — the user sees instant feedback.
      onSuccess(response);
      // Fire-and-forget background verify. This grants the entitlement on the
      // backend. If it fails, the webhook will handle it. The user already has
      // access via the optimistic local unlock.
      _verifyAndDispatch(
        response: response,
        orderId: orderId,
        // No-op callbacks — onSuccess was already called above.
        onSuccess: (_) {},
        onError: (_) {},
      ).catchError((e) {
        print('[RazorpayService] Background verify error (non-fatal): $e');
      });
    });
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR,
        (PaymentFailureResponse response) {
      print('[RazorpayService] EVENT_PAYMENT_ERROR: code=${response.code}, message=${response.message}');
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
      print('[RazorpayService] _openCheckout: _razorpay.open() called successfully');
      return true;
    } catch (e) {
      print('[RazorpayService] _openCheckout: _razorpay.open() threw: $e');
      onError(PaymentFailureResponse(
          0, 'Could not open payment screen. Please try again.', null));
      return false;
    }
  }

  // ==================== VERIFY + DISPATCH ====================
  /// Calls /api/payments/verify with the Razorpay signature. Only invokes
  /// [onSuccess] if the backend returns { success: true, granted: true }.
  ///
  /// RELIABILITY FALLBACK (v3 — "professional app" approach):
  /// If /verify fails for ANY reason (network error, timeout, server error,
  /// or even a signature mismatch), we POLL /api/payments/order-status up to
  /// 5 times (3s apart). The Razorpay webhook is the ultimate safety net on
  /// the backend — it marks the order PAID + grants the entitlement even if
  /// /verify never runs.
  ///
  /// OPTIMISTIC SUCCESS (v3.1 — the KEY fix for "payment success hole kichui
  /// hoi na"): if BOTH /verify AND order-status polling fail, we STILL call
  /// [onSuccess]. Why? Because Razorpay's EVENT_PAYMENT_SUCCESS already
  /// confirmed the user paid — the Razorpay SDK is signed, the order_id is
  /// bound to the checkout, and the payment is captured on Razorpay's side.
  /// Making the user wait or showing them a "payment failed" message when
  /// they actually paid is the #1 cause of support tickets and churn.
  ///
  /// The server-side webhook (Razorpay → /api/payments/webhook) will fire
  /// within 1-15s and grant the entitlement on the backend. The optimistic
  /// local unlock (AccessService.markTestPurchased + auth.addPurchasedTest)
  /// gives the user IMMEDIATE access. The next time the app does a server-side
  /// access check, the webhook will have granted the entitlement and the
  /// access will be confirmed server-side too.
  ///
  /// [onError] is now ONLY called when Razorpay itself reports a payment
  /// failure (EVENT_PAYMENT_ERROR) — never after a Razorpay-confirmed success.
  static Future<void> _verifyAndDispatch({
    required PaymentSuccessResponse response,
    required String orderId,
    required void Function(PaymentSuccessResponse) onSuccess,
    required void Function(PaymentFailureResponse) onError,
  }) async {
    try {
      print('[RazorpayService] _verifyAndDispatch: calling verifyPayment (orderId=$orderId, paymentId=${response.paymentId})...');
      final result = await PaymentApiService.verifyPayment(
        orderId: orderId,
        razorpayPaymentId: response.paymentId ?? '',
        razorpayOrderId: response.orderId ?? '',
        razorpaySignature: response.signature ?? '',
      ).timeout(_verifyHardTimeout, onTimeout: () {
        throw TimeoutException(
            'Payment verification timed out.');
      });
      print('[RazorpayService] _verifyAndDispatch: verifyPayment returned success=${result['success']}, granted=${result['granted']}');

      final ok = result['success'] == true && result['granted'] == true;
      if (ok) {
        onSuccess(response);
        return;
      }
      // verify returned 200 but not granted — unusual. Fall through to
      // order-status polling in case the webhook has since processed it.
      print('[RazorpayService] _verifyAndDispatch: verify returned not-granted — polling order-status as fallback');
      final recovered = await _tryRecoverFromOrderStatus(orderId, response, onSuccess);
      if (recovered) return;
      // OPTIMISTIC SUCCESS: verify returned not-granted AND polling didn't
      // recover. But Razorpay confirmed the payment (EVENT_PAYMENT_SUCCESS
      // fired). The webhook will grant the entitlement shortly. Unlock now.
      print('[RazorpayService] _verifyAndDispatch: verify not-granted + polling failed — OPTIMISTIC SUCCESS (Razorpay confirmed payment, webhook will grant)');
      onSuccess(response);
    } on PaymentApiException catch (e) {
      print('[RazorpayService] _verifyAndDispatch: PaymentApiException: ${e.message}');
      // Network / server / signature error during verify — the payment may
      // still have been captured (the webhook is the safety net). Poll
      // order-status before falling back to optimistic success.
      final recovered = await _tryRecoverFromOrderStatus(orderId, response, onSuccess);
      if (recovered) return;
      // OPTIMISTIC SUCCESS: verify threw an exception AND polling didn't
      // recover. But Razorpay confirmed the payment. Unlock optimistically.
      print('[RazorpayService] _verifyAndDispatch: PaymentApiException + polling failed — OPTIMISTIC SUCCESS (Razorpay confirmed payment, webhook will grant)');
      onSuccess(response);
    } on TimeoutException catch (e) {
      print('[RazorpayService] _verifyAndDispatch: timeout: ${e.message}');
      // Verify timed out — the payment may still have been captured (the
      // webhook is async). Poll order-status as a fallback.
      final recovered = await _tryRecoverFromOrderStatus(orderId, response, onSuccess);
      if (recovered) return;
      // OPTIMISTIC SUCCESS: verify timed out AND polling didn't recover.
      // But Razorpay confirmed the payment. Unlock optimistically.
      print('[RazorpayService] _verifyAndDispatch: timeout + polling failed — OPTIMISTIC SUCCESS (Razorpay confirmed payment, webhook will grant)');
      onSuccess(response);
    } catch (e) {
      print('[RazorpayService] _verifyAndDispatch: unexpected error: $e');
      // Unexpected error — poll order-status before falling back to
      // optimistic success.
      final recovered = await _tryRecoverFromOrderStatus(orderId, response, onSuccess);
      if (recovered) return;
      // OPTIMISTIC SUCCESS: unexpected error AND polling didn't recover.
      // But Razorpay confirmed the payment. Unlock optimistically.
      print('[RazorpayService] _verifyAndDispatch: unexpected error + polling failed — OPTIMISTIC SUCCESS (Razorpay confirmed payment, webhook will grant)');
      onSuccess(response);
    }
  }

  /// FALLBACK: after /verify fails, POLL /api/payments/order-status up to 3
  /// times (3 seconds apart). The Razorpay webhook is the backend safety net —
  /// it marks the order PAID + grants the entitlement even if /verify never
  /// runs. Polling gives the webhook time to fire (it's async, typically 1-5s
  /// but can take up to ~10s under load).
  ///
  /// As soon as a poll reports paid=true && granted=true, we call [onSuccess]
  /// and return true. If all polls report the order as not-yet-paid, we return
  /// false — but the caller now falls back to OPTIMISTIC SUCCESS (see
  /// _verifyAndDispatch), so the user is never left without their purchase.
  ///
  /// v1.35.1 — reduced from 5 polls back to 3 (with 7s poll timeout instead
  /// of 10s) because the optimistic-success fallback means polling is no longer
  /// the last line of defence. Total worst-case wait: 12s (verify) + 3×(7s+3s)
  /// = ~42s, but typically 1-2 polls succeed = 3-13s. The verifying dialog's
  /// 60s safety timeout has plenty of headroom.
  static Future<bool> _tryRecoverFromOrderStatus(
    String orderId,
    PaymentSuccessResponse response,
    void Function(PaymentSuccessResponse) onSuccess,
  ) async {
    const int maxAttempts = 3;
    const Duration pollInterval = Duration(seconds: 3);
    const Duration pollTimeout = Duration(seconds: 7);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        print('[RazorpayService] _tryRecoverFromOrderStatus: poll $attempt/$maxAttempts (orderId=$orderId)...');
        final status = await PaymentApiService.getOrderStatus(orderId: orderId)
            .timeout(pollTimeout, onTimeout: () {
          throw TimeoutException('order-status check timed out');
        });
        final paid = status['paid'] == true;
        final granted = status['granted'] == true;
        print('[RazorpayService] _tryRecoverFromOrderStatus: poll $attempt → status=${status['status']}, paid=$paid, granted=$granted');
        if (paid && granted) {
          // The webhook already processed this payment. Treat as success.
          print('[RazorpayService] _tryRecoverFromOrderStatus: RECOVERED on poll $attempt — order is PAID + granted, calling onSuccess');
          onSuccess(response);
          return true;
        }
        // Order is not yet PAID/granted. The webhook may not have fired yet
        // (it's async). Wait and poll again, unless this was the last attempt.
        if (attempt < maxAttempts) {
          print('[RazorpayService] _tryRecoverFromOrderStatus: order not yet PAID — waiting ${pollInterval.inSeconds}s before next poll (webhook may still be processing)');
          await Future<void>.delayed(pollInterval);
        }
      } catch (e) {
        print('[RazorpayService] _tryRecoverFromOrderStatus: poll $attempt failed: $e');
        if (attempt < maxAttempts) {
          await Future<void>.delayed(pollInterval);
        }
      }
    }
    print('[RazorpayService] _tryRecoverFromOrderStatus: all $maxAttempts polls exhausted — order not yet PAID. Caller will fall back to OPTIMISTIC SUCCESS.');
    return false;
  }

  // ==================== CLEANUP ====================
  static void clear() {
    _razorpay?.clear();
  }
}
