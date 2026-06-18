import 'package:flutter/material.dart';

import '../../../domain/services/analytics_service.dart';

/// GitHub-style activity heatmap: a grid of colored cells, one per day.
///
/// Cells are arranged in columns by week. Each column is a week (Mon-Sun),
/// and rows are days of the week (Mon=0 to Sun=6).
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    super.key,
    required this.data,
  });

  final List<HeatmapDay> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const _EmptyChart(message: 'Log climbs to see your activity heatmap');
    }

    // Pad to start on Monday and end on Sunday for clean grid columns
    final firstDate = data.first.date;
    final lastDate = data.last.date;

    // Find the Monday before (or on) firstDate
    final startMonday = firstDate.subtract(Duration(days: firstDate.weekday - 1));
    // Find the Sunday after (or on) lastDate
    final endSunday = lastDate.add(Duration(days: DateTime.daysPerWeek - lastDate.weekday));

    // Build a lookup map
    final Map<String, int> countMap = {};
    for (final day in data) {
      final key = '${day.date.year}-${day.date.month}-${day.date.day}';
      countMap[key] = day.climbCount;
    }

    // Determine max count for color intensity
    final maxCount = countMap.values.isEmpty
        ? 0
        : countMap.values.reduce((a, b) => a > b ? a : b);

    // Columns: one per week
    // Rows: Mon=0 (top) through Sun=6 (bottom)
    final totalDays = endSunday.difference(startMonday).inDays + 1;
    final weeks = (totalDays / 7).ceil();

    return SizedBox(
      height: 140,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Day labels
          const _DayLabels(),
          const SizedBox(width: 4),
          // Heatmap grid
          for (int col = 0; col < weeks; col++)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int row = 0; row < 7; row++)
                  _Cell(
                    date: startMonday.add(Duration(days: col * 7 + row)),
                    count: countMap,
                    maxCount: maxCount,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.date,
    required this.count,
    required this.maxCount,
  });

  final DateTime date;
  final Map<String, int> count;
  final int maxCount;

  static const _cellSize = 14.0;
  static const _cellGap = 2.0;

  Color _color(int count, int max) {
    if (count == 0) {
      return const Color(0xFFE0E0E0); // empty cell
    }
    final intensity = max > 0 ? count / max : 0.0;
    // Scale from light green to dark green
    return Color.lerp(
      const Color(0xFFC8E6C9),
      const Color(0xFF2E7D32),
      intensity,
    )!;
  }

  @override
  Widget build(BuildContext context) {
    final key = '${date.year}-${date.month}-${date.day}';
    final c = count[key] ?? 0;

    return Tooltip(
      message: '${date.month}/${date.day}: $c climb${c == 1 ? '' : 's'}',
      child: Container(
        width: _cellSize,
        height: _cellSize,
        margin: const EdgeInsets.all(_cellGap / 2),
        decoration: BoxDecoration(
          color: _color(c, maxCount),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _DayLabels extends StatelessWidget {
  const _DayLabels();

  static const _labels = ['Mon', '', 'Wed', '', 'Fri', '', ''];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 7; i++)
          SizedBox(
            width: 28,
            height: _Cell._cellSize + _Cell._cellGap,
            child: Center(
              child: Text(
                _labels[i],
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ),
          ),
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
      height: 140,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );
  }
}
