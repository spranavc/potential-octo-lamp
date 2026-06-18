import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../domain/services/analytics_service.dart';

/// Horizontal bar chart showing send rate (percentage) per grade.
class SendRateChart extends StatelessWidget {
  const SendRateChart({
    super.key,
    required this.data,
  });

  final List<SendRatePoint> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _EmptyChart(message: 'Log climbs to see send rates by grade');
    }

    return SizedBox(
      height: data.length * 40.0 + 40, // dynamic height based on bars
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.center,
          barGroups: data.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: point.sendRate * 100, // show as percentage
                  width: 22,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                  color: _rateColor(point.sendRate),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    data[i].gradeLabel,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
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
            drawVerticalLine: true,
            drawHorizontalLine: false,
          ),
          borderData: FlBorderData(show: false),
          maxY: 100,
          minY: 0,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) {
                final point = data[group.x.toInt()];
                return BarTooltipItem(
                  '${point.gradeLabel}: ${(point.sendRate * 100).toStringAsFixed(0)}%\n(${point.totalAttempts} attempts)',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
        ),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Color scales from red (low) to yellow to green (high).
  Color _rateColor(double rate) {
    if (rate < 0.33) return const Color(0xFFEF5350);
    if (rate < 0.66) return const Color(0xFFFFC107);
    return const Color(0xFF4CAF50);
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
