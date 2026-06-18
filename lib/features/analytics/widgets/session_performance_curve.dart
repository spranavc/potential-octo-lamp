// ignore_for_file: unnecessary_underscores

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../domain/services/performance_service.dart';

/// Chart showing climb grade vs. order within a session.
///
/// Green dots = sends, red dots = fails. A trend line (rolling average) shows
/// the overall performance curve, revealing when the climber peaks during a
/// session.
class SessionPerformanceCurve extends StatelessWidget {
  const SessionPerformanceCurve({
    super.key,
    required this.points,
    required this.trend,
    required this.sessionDate,
    required this.climbCount,
  });

  final List<SessionPerformancePoint> points;
  final List<RollingAveragePoint> trend;
  final DateTime sessionDate;
  final int climbCount;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _EmptyChart(message: 'No graded climbs in this session');
    }

    final minGrade = points.map((p) => p.gradeNum).reduce(
          (a, b) => a < b ? a : b,
        ) -
        1;
    final maxGrade = points.map((p) => p.gradeNum).reduce(
          (a, b) => a > b ? a : b,
        ) +
        1;

    final maxClimbOrder = points.last.climbOrder;

    // Separate sends and fails into their own spot lists
    final sendSpots = <FlSpot>[];
    final failSpots = <FlSpot>[];
    for (final point in points) {
      final spot = FlSpot(point.climbOrder.toDouble(), point.gradeNum.toDouble());
      if (point.sent) {
        sendSpots.add(spot);
      } else {
        failSpots.add(spot);
      }
    }

    return SizedBox(
      height: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                _LegendDot(color: Color(0xFF4CAF50), label: 'Send'),
                SizedBox(width: 12),
                _LegendDot(color: Color(0xFFEF5350), label: 'Fail'),
                SizedBox(width: 12),
                _LegendDot(color: Color(0xFF2196F3), label: 'Trend'),
              ],
            ),
          ),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (maxClimbOrder + 1).toDouble(),
                minY: minGrade.clamp(0, 17).toDouble(),
                maxY: maxGrade.clamp(1, 17).toDouble(),
                lineBarsData: [
                  // Sends: dots only, no line
                  LineChartBarData(
                    spots: sendSpots,
                    show: sendSpots.isNotEmpty,
                    color: const Color(0xFF4CAF50),
                    barWidth: 0, // no line
                    isStrokeCapRound: false,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) =>
                          FlDotCirclePainter(
                        radius: 5,
                        color: const Color(0xFF4CAF50),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                  ),
                  // Fails: dots only, no line
                  LineChartBarData(
                    spots: failSpots,
                    show: failSpots.isNotEmpty,
                    color: const Color(0xFFEF5350),
                    barWidth: 0,
                    isStrokeCapRound: false,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) =>
                          FlDotCirclePainter(
                        radius: 5,
                        color: const Color(0xFFEF5350),
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                  ),
                  // Trend line
                  if (trend.isNotEmpty)
                    LineChartBarData(
                      spots: trend
                          .map((p) => FlSpot(
                                p.climbOrder.toDouble(),
                                p.averageGrade,
                              ))
                          .toList(),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: const Color(0xFF2196F3).withAlpha(180),
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF2196F3).withAlpha(30),
                      ),
                    ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text(
                      'Climb Order',
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
                      reservedSize: 36,
                      interval: 1,
                      getTitlesWidget: (value, _) {
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
                lineTouchData: const LineTouchData(enabled: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
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
