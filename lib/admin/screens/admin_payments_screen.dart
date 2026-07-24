// =============================================================================
// ExamVault - Admin Payments Screen
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/payment_model.dart';
import '../../services/firebase_service.dart';

class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder(
        stream: FirebaseService.paymentsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_off, size: 56, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade500),
                    const SizedBox(height: 12),
                    const Text('Failed to load', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(snapshot.error.toString(), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No payments'));
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final payment = PaymentModel.fromFirestore(docs[index]);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(payment.planName),
                  subtitle: Text('₹${payment.amount ~/ 100} • ${payment.status.name}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(payment.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      payment.status.name.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(payment.status),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.captured: return AppTheme.successColor;
      case PaymentStatus.failed: return AppTheme.errorColor;
      case PaymentStatus.refunded: return Colors.orange;
      case PaymentStatus.pending: return Colors.blue;
      default: return Colors.grey;
    }
  }
}
