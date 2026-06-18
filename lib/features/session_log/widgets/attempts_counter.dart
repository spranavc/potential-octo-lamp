import 'package:flutter/material.dart';

/// A simple tap-based attempts counter.
class AttemptsCounter extends StatelessWidget {
  const AttemptsCounter({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final void Function(int newValue) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'attempt${value == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(width: 16),
        IconButton.filled(
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
