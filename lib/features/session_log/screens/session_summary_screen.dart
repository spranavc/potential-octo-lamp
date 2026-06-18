import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/active_session_provider.dart';

class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeSessionProvider);

    if (!state.isActive) {
      // Session was already ended, return to log
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/session-log');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Session Summary')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stats cards
            Row(
              children: [
                _StatCard(
                  label: 'Total Climbs',
                  value: '${state.totalCount}',
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Sends',
                  value: '${state.sendCount}',
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Fails',
                  value: '${state.failCount}',
                  color: Colors.red,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Send rate
            if (state.totalCount > 0)
              _StatCard(
                label: 'Send Rate',
                value: '${(state.sendCount / state.totalCount * 100).round()}%',
                color: Colors.orange,
              ),

            const SizedBox(height: 24),

            // Duration
            if (state.startedAt != null)
              Text(
                'Session started at ${_formatTime(state.startedAt!)}',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),

            const Spacer(),

            // Actions
            FilledButton(
              onPressed: () {
                ref.read(activeSessionProvider.notifier).end();
                context.go('/session-log');
              },
              child: const Text('Save & Finish'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                ref.read(activeSessionProvider.notifier).cancel();
                context.go('/session-log');
              },
              child: const Text('Discard Session'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hour:$min $amPm';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
