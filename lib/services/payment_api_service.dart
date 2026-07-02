// =============================================================================
// ExamVault - Payment API Service (server-side-verified Razorpay flow)
// =============================================================================
// This service wraps all calls to the Next.js payment API on the admin panel
// origin (AppConfig.apiBaseUrl). The Flutter app NEVER writes payment success
// to Firestore directly — every successful Razorpay checkout is verified by
// the backend via /api/payments/verify, and only the backend grants access.
//
// All requests carry the current Firebase user's ID token in the
// `Authorization: Bearer <token>` header so the backend can identify the user.
// =============================================================================

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Typed exception thrown by [PaymentApiService] on any non-2xx response or
/// transport error. Callers should catch this and surface `message` to the
/// user (it is already user-friendly where possible).
class PaymentApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? endpoint;

  const PaymentApiException(this.message, {this.statusCode, this.endpoint});

  @override
  String toString() => message;
}

class PaymentApiService {
  PaymentApiService._();

  // 30-second timeout — Razorpay order creation hits Razorpay's server from
  // the backend, which can occasionally be slow. Anything longer is suspect.
  static const Duration _timeout = Duration(seconds: 30);

  /// Returns the current Firebase user's ID token, or throws a
  /// [PaymentApiException] if there is no signed-in user (the payment API
  /// requires authentication).
  static Future<String> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const PaymentApiException(
        'You need to be signed in to make a purchase. Please log in and try again.',
      );
    }
    // forceRefresh: false — use cached token if still valid (fast path).
    final token = await user.getIdToken(false);
    if (token == null || token.isEmpty) {
      throw const PaymentApiException(
        'Your session has expired. Please log in again and retry.',
      );
    }
    return token;
  }

  /// Builds the default headers, including the Bearer token.
  static Future<Map<String, String>> _headers({
    bool jsonBody = true,
  }) async {
    final token = await _getIdToken();
    final h = <String, String>{
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    if (jsonBody) h['Content-Type'] = 'application/json';
    return h;
  }

  /// Centralized POST helper. Decodes JSON, throws [PaymentApiException] on
  /// non-2xx. Returns the decoded body (Map or List) on success.
  static Future<dynamic> _post(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    try {
      final res = await http
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      return _decode(res, path);
    } on PaymentApiException {
      rethrow;
    } catch (e) {
      throw PaymentApiException(
        'Network error. Please check your internet connection and try again.',
        endpoint: path,
      );
    }
  }

  /// Centralized GET helper.
  static Future<dynamic> _get(String path) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    try {
      final res = await http
          .get(uri, headers: await _headers(jsonBody: false))
          .timeout(_timeout);
      return _decode(res, path);
    } on PaymentApiException {
      rethrow;
    } catch (e) {
      throw PaymentApiException(
        'Network error. Please check your internet connection and try again.',
        endpoint: path,
      );
    }
  }

  /// Decodes an HTTP response. Throws [PaymentApiException] on non-2xx.
  /// 404 is special-cased so callers can show the "feature being rolled out"
  /// friendly message for endpoints the admin hasn't built yet.
  static dynamic _decode(http.Response res, String path) {
    final status = res.statusCode;
    // 404 — endpoint not built yet. Surface as a friendly message.
    if (status == 404) {
      throw PaymentApiException(
        'This feature is being rolled out. Please update the app soon.',
        statusCode: 404,
        endpoint: path,
      );
    }
    // 401 / 403 — auth problem. Tell the user to re-login.
    if (status == 401 || status == 403) {
      throw PaymentApiException(
        'Your session has expired. Please log in again and retry.',
        statusCode: status,
        endpoint: path,
      );
    }
    // Try to decode the body as JSON regardless of status (the backend always
    // returns JSON for errors with a `message` or `error` field).
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      decoded = null;
    }

    if (status < 200 || status >= 300) {
      // Try to extract a server-provided message.
      String msg;
      if (decoded is Map) {
        msg = (decoded['message'] ??
                decoded['error'] ??
                decoded['detail'] ??
                '')
            .toString();
      } else {
        msg = '';
      }
      if (msg.isEmpty) {
        msg = 'Request failed (HTTP $status). Please try again.';
      }
      throw PaymentApiException(msg, statusCode: status, endpoint: path);
    }

    // Success — return decoded body if it's a Map/List, else the raw string.
    if (decoded is Map || decoded is List) return decoded;
    return <String, dynamic>{};
  }

  // ==================== API METHODS ====================

  /// `POST /api/payments/create-order`
  ///
  /// Creates a Razorpay order on the backend. Returns the server response,
  /// which has the shape:
  ///   { orderId, orderRef, razorpayOrderId, amount (paise), currency,
  ///     productType, productId, productName, keyId }
  static Future<Map<String, dynamic>> createOrder({
    required String productType,
    required String productId,
    required String productName,
    required double amountRupees,
    required String idempotencyKey,
    Map<String, dynamic>? meta,
  }) async {
    final body = <String, dynamic>{
      'productType': productType,
      'productId': productId,
      'productName': productName,
      'amount': amountRupees, // RUPEES — backend converts to paise
      'idempotencyKey': idempotencyKey,
      if (meta != null) 'meta': meta,
    };
    final res = await _post('/api/payments/create-order', body: body);
    if (res is! Map) {
      throw const PaymentApiException('Unexpected response from server.');
    }
    return Map<String, dynamic>.from(res);
  }

  /// `POST /api/payments/verify`
  ///
  /// Verifies a Razorpay payment signature server-side. Returns the server
  /// response, which has the shape:
  ///   { success, paymentId, productType, productId, granted }
  /// Only treat the content as unlocked when `success == true && granted == true`.
  static Future<Map<String, dynamic>> verifyPayment({
    required String orderId, // Prisma Order id from create-order response
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    final body = <String, dynamic>{
      'orderId': orderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpayOrderId': razorpayOrderId,
      'razorpaySignature': razorpaySignature,
    };
    final res = await _post('/api/payments/verify', body: body);
    if (res is! Map) {
      throw const PaymentApiException('Unexpected response from server.');
    }
    return Map<String, dynamic>.from(res);
  }

  /// `GET /api/payments/access-check?type=test|subject|exam|all&...`
  ///
  /// Returns { allowed, reason, grantedBy?, sourceId?, expiresAt? }.
  static Future<Map<String, dynamic>> checkAccess({
    required String type,
    String? testId,
    String? subjectId,
    String? categoryId,
  }) async {
    final qs = <String, String>{'type': type};
    if (testId != null) qs['testId'] = testId;
    if (subjectId != null) qs['subjectId'] = subjectId;
    if (categoryId != null) qs['categoryId'] = categoryId;
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/payments/access-check')
        .replace(queryParameters: qs);
    try {
      final res = await http
          .get(uri, headers: await _headers(jsonBody: false))
          .timeout(_timeout);
      final decoded = _decode(res, '/api/payments/access-check');
      if (decoded is! Map) {
        throw const PaymentApiException('Unexpected response from server.');
      }
      return Map<String, dynamic>.from(decoded);
    } on PaymentApiException {
      rethrow;
    } catch (e) {
      throw PaymentApiException(
        'Network error. Please check your internet connection and try again.',
        endpoint: '/api/payments/access-check',
      );
    }
  }

  /// `POST /api/payments/retry` — retry a previously-created order (e.g. the
  /// user closed Razorpay mid-checkout). Returns the same shape as create-order.
  static Future<Map<String, dynamic>> retryOrder({
    required String orderId,
  }) async {
    final res = await _post('/api/payments/retry', body: {'orderId': orderId});
    if (res is! Map) {
      throw const PaymentApiException('Unexpected response from server.');
    }
    return Map<String, dynamic>.from(res);
  }

  /// `GET /api/payments/invoice/[paymentId]` — returns the FULL URL the caller
  /// should open in a webview / url_launcher. The endpoint returns HTML; we
  /// don't fetch it here, we just build the URL.
  static Future<String> getInvoiceUrl(String paymentId) async {
    // No network call needed — just construct the URL. (Kept async for API
    // symmetry and so we can validate auth locally first.)
    await _getIdToken();
    return '${AppConfig.apiBaseUrl}/api/payments/invoice/$paymentId';
  }

  /// `POST /api/payments/cancel-subscription` — cancel the user's active
  /// premium subscription. May 404 if the admin hasn't built it yet — callers
  /// should catch PaymentApiException and show the friendly "rolled out" msg.
  static Future<Map<String, dynamic>> cancelSubscription() async {
    final res =
        await _post('/api/payments/cancel-subscription', body: <String, dynamic>{});
    if (res is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(res);
  }

  /// `GET /api/user/purchases` — fetch the current user's purchase dashboard.
  /// May 404 if the admin hasn't built user routes yet — callers should catch
  /// [PaymentApiException] (statusCode 404) and show the friendly message.
  /// Returns the raw decoded body (caller shapes it). On any failure returns
  /// an empty map so screens can render an empty state without crashing.
  static Future<Map<String, dynamic>> getUserPurchases() async {
    final res = await _get('/api/user/purchases');
    if (res is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(res);
  }
}
