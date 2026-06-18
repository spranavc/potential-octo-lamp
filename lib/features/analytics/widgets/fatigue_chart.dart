import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../domain/services/performance_service.dart';

/// Line chart showing average RPE over climb order within a session.
///
/// Rising RPE indicates accumulating fatigue. Annotations highlight the
/// "wall" where fatigue starts to significantly impact performance.
class FatigueChart extends StatelessWidget {
  const FatigueChart({
    super.key,
    required this.data,
  });

  final List<FatiguePoint> data;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) {
      return const _EmptyChart(
        message: 'Log RPE on climbs across multiple sessions to see fatigue trends',
      );
    }

    final maxClimbOrder = data.last.climbOrder;

    final spots = data
        .map((p) => FlSpot(p.climbOrder.toDouble(), p.rpe))
        .toList();

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (maxClimbOrder + 1).toDouble(),
          minY: 0,
          maxY: 10,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: const Color(0xFFFF9800),
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFFFF9800),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFFF9800).withAlpha(40),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text(
                'Climb Order in Session',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: maxClimbOrder > 15 ? 5 : 1,
                getTitlesWidget: (value, _) {
                  if (value <= 0) return const SizedBox.shrink();
                  return Text(
                    '${value.toInt()}',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 2,
                getTitlesWidget: (value, _) {
                  return Text(
                    'RPE ${value.toInt()}',
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
            drawVerticalLine: false,
            horizontalInterval: 2,
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                return LineTooltipItem(
                  'Climb ${s.x.toInt()}: RPE ${s.y.toStringAsFixed(1)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList(),
            ),
          ),
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
