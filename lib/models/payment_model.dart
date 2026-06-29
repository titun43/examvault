// =============================================================================
// ExamVault - Payment Model (Razorpay)
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus { created, authorized, captured, failed, refunded, pending }
enum PaymentMethod { upi, card, netbanking, wallet, emi }

class PaymentModel {
  final String id;
  final String userId;
  final String razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final int amount; // in paise
  final String currency;
  final PaymentStatus status;
  final PaymentMethod? method;
  final String planId;
  final String planName;
  final int durationMonths;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic> rawResponse;

  PaymentModel({
    required this.id,
    required this.userId,
    required this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    required this.amount,
    this.currency = 'INR',
    this.status = PaymentStatus.created,
    this.method,
    required this.planId,
    required this.planName,
    required this.durationMonths,
    required this.createdAt,
    this.completedAt,
    this.rawResponse = const {},
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      razorpayOrderId: data['razorpayOrderId'] ?? '',
      razorpayPaymentId: data['razorpayPaymentId'],
      razorpaySignature: data['razorpaySignature'],
      amount: data['amount'] ?? 0,
      currency: data['currency'] ?? 'INR',
      status: _parseStatus(data['status']),
      method: _parseMethod(data['method']),
      planId: data['planId'] ?? '',
      planName: data['planName'] ?? '',
      durationMonths: data['durationMonths'] ?? 1,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      rawResponse: data['rawResponse'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'method': method?.name,
      'planId': planId,
      'planName': planName,
      'durationMonths': durationMonths,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'rawResponse': rawResponse,
    };
  }

  static PaymentStatus _parseStatus(String? status) {
    switch (status) {
      case 'authorized': return PaymentStatus.authorized;
      case 'captured': return PaymentStatus.captured;
      case 'failed': return PaymentStatus.failed;
      case 'refunded': return PaymentStatus.refunded;
      case 'pending': return PaymentStatus.pending;
      default: return PaymentStatus.created;
    }
  }

  static PaymentMethod? _parseMethod(String? method) {
    switch (method) {
      case 'upi': return PaymentMethod.upi;
      case 'card': return PaymentMethod.card;
      case 'netbanking': return PaymentMethod.netbanking;
      case 'wallet': return PaymentMethod.wallet;
      case 'emi': return PaymentMethod.emi;
      default: return null;
    }
  }
}
