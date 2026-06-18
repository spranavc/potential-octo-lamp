import 'package:flutter/material.dart';

class ProjectProgressBar extends StatelessWidget {
  const ProjectProgressBar({
    super.key,
    required this.sentClimbs,
    required this.totalClimbs,
  });

  final int sentClimbs;
  final int totalClimbs;

  double get _fraction => totalClimbs > 0 ? sentClimbs / totalClimbs : 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Progress', style: theme.textTheme.titleMedium),
            Text(
              '${(_fraction * 100).toStringAsFixed(0)}% sent ($sentClimbs/$totalClimbs)',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _fraction,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
