// =============================================================================
// ExamVault - Admin Payments Screen (offline)
// =============================================================================

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_data_service.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  late List<LocalPayment> _items;

  @override
  void initState() {
    super.initState();
    _items = LocalDataService.getPayments();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'success':
        return AppTheme.successColor;
      case 'failed':
        return AppTheme.errorColor;
      case 'pending':
        return Colors.blue;
      case 'refunded':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        automaticallyImplyLeading: false,
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No payments'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final p = _items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('${p.userName} — ${p.plan}'),
                    subtitle: Text(
                        '₹${p.amount} • ${p.date.day}/${p.date.month}/${p.date.year} • ${p.id}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(p.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.status.toUpperCase(),
                        style: TextStyle(
                          color: _statusColor(p.status),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
