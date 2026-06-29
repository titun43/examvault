// =============================================================================
// ExamVault - Admin Analytics Screen (offline — uses dashboardStats)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../services/local_data_service.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = LocalDataService.dashboardStats();
    final categories = LocalDataService.getCategories();
    final tests = LocalDataService.getTests();

    // Tests per category
    final bars = <BarChartGroupData>[];
    for (var i = 0; i < categories.length && i < 6; i++) {
      final count =
          tests.where((t) => t.categoryId == categories[i].id).length;
      bars.add(_buildBarGroup(
        i,
        count.toDouble(),
        AppTheme.categoryColors[categories[i].name] ?? AppTheme.primaryColor,
      ));
    }

    // Revenue by plan (pie)
    final payments = LocalDataService.getPayments();
    final planTotals = <String, int>{};
    for (final p in payments) {
      planTotals[p.plan] = (planTotals[p.plan] ?? 0) + p.amount;
    }
    final pieColors = <String, Color>{
      'Monthly': AppTheme.primaryColor,
      'Quarterly': AppTheme.accentColor,
      'Yearly': Colors.purple,
    };
    final pieSections = planTotals.entries.toList().asMap().entries.map((e) {
      final plan = e.value.key;
      final amt = e.value.value;
      return PieChartSectionData(
        value: amt.toDouble(),
        color: pieColors[plan] ?? Colors.grey,
        title: '$plan\n₹$amt',
        radius: 80,
        titleStyle: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary stat cards
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statChip('Users', stats['totalUsers'].toString(), Icons.people),
                _statChip('Premium', stats['premiumUsers'].toString(),
                    Icons.workspace_premium),
                _statChip('Tests', stats['totalTests'].toString(), Icons.quiz),
                _statChip('Questions', stats['totalQuestions'].toString(),
                    Icons.question_answer),
                _statChip('Revenue ₹', stats['totalRevenue'].toString(),
                    Icons.currency_rupee),
                _statChip('Categories', stats['totalCategories'].toString(),
                    Icons.category),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Tests by Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: bars.isEmpty
                    ? const SizedBox(
                        height: 200, child: Center(child: Text('No data')))
                    : SizedBox(
                        height: 250,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            barGroups: bars,
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, _) {
                                    final i = v.toInt();
                                    if (i < 0 || i >= categories.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(categories[i].name,
                                          style: const TextStyle(fontSize: 10)),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Revenue by Plan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: pieSections.isEmpty
                    ? const SizedBox(
                        height: 200, child: Center(child: Text('No payments')))
                    : SizedBox(
                        height: 250,
                        child: PieChart(
                          PieChartData(
                            sections: pieSections,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 18),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          color: color,
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }
}
