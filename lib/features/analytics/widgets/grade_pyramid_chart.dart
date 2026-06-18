import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../domain/services/analytics_service.dart';

/// Stacked vertical bar chart showing sends (green) and fails (red) per V-grade.
class GradePyramidChart extends StatelessWidget {
  const GradePyramidChart({
    super.key,
    required this.data,
  });

  final List<GradeDistributionPoint> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _EmptyChart(message: 'Log climbs to see your grade pyramid');
    }

    final maxY = data
        .map((d) => d.sends + d.fails)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return SizedBox(
      height: 280,
      child: BarChart(
        BarChartData(
          maxY: maxY < 1 ? 1 : maxY + 1,
          alignment: BarChartAlignment.center,
          barGroups: data.map((point) {
            return BarChartGroupData(
              x: point.gradeNum,
              barRods: [
                BarChartRodData(
                  toY: (point.sends + point.fails).toDouble(),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  rodStackItems: [
                    BarChartRodStackItem(
                      0,
                      point.sends.toDouble(),
                      const Color(0xFF4CAF50), // green — sends
                    ),
                    BarChartRodStackItem(
                      point.sends.toDouble(),
                      (point.sends + point.fails).toDouble(),
                      const Color(0xFFEF5350), // red — fails
                    ),
                  ],
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  // Show every other label to avoid crowding
                  if (i % 2 == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'V$i',
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );
  }
}
