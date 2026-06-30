// =============================================================================
// ExamVault - Admin Analytics Screen
// =============================================================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            const Text(
              'User Growth (Last 7 Days)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 250,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: const FlTitlesData(show: true),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [
                            const FlSpot(0, 10),
                            const FlSpot(1, 25),
                            const FlSpot(2, 40),
                            const FlSpot(3, 35),
                            const FlSpot(4, 60),
                            const FlSpot(5, 75),
                            const FlSpot(6, 90),
                          ],
                          isCurved: true,
                          color: AppTheme.primaryColor,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                child: SizedBox(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      barGroups: [
                        _buildBarGroup(0, 25, AppTheme.categoryColors['Railway']!),
                        _buildBarGroup(1, 20, AppTheme.categoryColors['SSC']!),
                        _buildBarGroup(2, 30, AppTheme.categoryColors['UPSC']!),
                        _buildBarGroup(3, 15, AppTheme.categoryColors['Banking']!),
                        _buildBarGroup(4, 18, AppTheme.categoryColors['ADRE']!),
                        _buildBarGroup(5, 22, AppTheme.categoryColors['State Exams']!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Revenue (Monthly)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      sections: [
                        PieChartSectionData(
                          value: 45,
                          color: AppTheme.primaryColor,
                          title: 'Monthly\n45%',
                          radius: 80,
                        ),
                        PieChartSectionData(
                          value: 30,
                          color: AppTheme.accentColor,
                          title: 'Quarterly\n30%',
                          radius: 80,
                        ),
                        PieChartSectionData(
                          value: 25,
                          color: Colors.purple,
                          title: 'Yearly\n25%',
                          radius: 80,
                        ),
                      ],
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
