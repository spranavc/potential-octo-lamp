import 'package:flutter/material.dart';

/// Rate of Perceived Exertion slider (1-10).
class RpeSlider extends StatelessWidget {
  const RpeSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double? value;
  final void Function(double? newValue) onChanged;

  @override
  Widget build(BuildContext context) {
    final displayValue = value?.round() ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (displayValue > 0)
              Text(
                'RPE: $displayValue',
                style: Theme.of(context).textTheme.titleSmall,
              )
            else
              const Text('RPE', style: TextStyle(color: Colors.grey)),
            Text(
              _rpeLabel(displayValue),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        Slider(
          value: value ?? 0,
          min: 0,
          max: 10,
          divisions: 10,
          onChanged: (v) {
            if (v == 0) {
              onChanged(null);
            } else {
              onChanged(v);
            }
          },
        ),
      ],
    );
  }

  String _rpeLabel(int rpe) {
    const labels = [
      '',          // 0
      'Very light', // 1
      'Light',     // 2
      'Moderate',  // 3
      'Somewhat hard', // 4
      'Hard',      // 5
      '',          // 6
      'Very hard', // 7
      '',          // 8
      'Max effort', // 9
      'Limit',     // 10
    ];
    return rpe < labels.length ? labels[rpe] : '';
  }
}
