import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../domain/services/analytics_service.dart';

/// Line chart showing hardest sends over time (cumulative max grade per week).
class HardestSendsChart extends StatelessWidget {
  const HardestSendsChart({
    super.key,
    required this.data,
  });

  final List<ProgressionPoint> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _EmptyChart(message: 'Log sends to see your progression');
    }

    final minY = (data.map((p) => p.maxGrade).reduce((a, b) => a < b ? a : b) - 1)
        .clamp(0, 17)
        .toDouble();
    final maxY = (data.map((p) => p.maxGrade).reduce((a, b) => a > b ? a : b) + 1)
        .clamp(1, 17)
        .toDouble();

    final spots = data
        .asMap()
        .entries
        .map((entry) {
          return FlSpot(entry.key.toDouble(), entry.value.maxGrade.toDouble());
        })
        .toList();

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: const Color(0xFF2196F3),
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, _, _) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: const Color(0xFF2196F3),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF2196F3).withAlpha(40),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: data.length > 6 ? (data.length / 5).ceil().toDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) {
                    return const SizedBox.shrink();
                  }
                  final date = data[i].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: maxY - minY <= 5 ? 1 : 2,
                getTitlesWidget: (value, meta) {
                  return Text(
                    'V${value.toInt()}',
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
