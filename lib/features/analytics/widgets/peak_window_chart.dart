import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../domain/services/performance_service.dart';

/// Horizontal bar chart showing send rates by time-of-day window.
///
/// Displays which 2-hour blocks have the highest success rates, helping the
/// user identify their peak performance time. Bars are colored by send rate
/// (red → yellow → green).
class PeakWindowChart extends StatelessWidget {
  const PeakWindowChart({
    super.key,
    required this.data,
  });

  final List<PeakWindowBucket> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _EmptyChart(
        message: 'Log more climbs to see your peak performance times',
      );
    }

    return SizedBox(
      height: data.length * 42.0 + 40,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.center,
          barGroups: data.asMap().entries.map((entry) {
            final index = entry.key;
            final bucket = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: bucket.sendRate * 100,
                  width: 18,
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(4)),
                  color: _rateColor(bucket.sendRate),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 82,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    data[i].label,
                    style: const TextStyle(fontSize: 11),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text(
                'Send Rate',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
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
                final bucket = data[group.x.toInt()];
                return BarTooltipItem(
                  '${bucket.label}\n${(bucket.sendRate * 100).toStringAsFixed(0)}% (${bucket.totalClimbs} climbs)',
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
