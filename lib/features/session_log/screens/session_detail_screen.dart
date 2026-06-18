import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';
import '../providers/session_detail_provider.dart';

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final climbsAsync = ref.watch(sessionClimbsProvider(sessionId));
    final sessionAsync = ref.watch(sessionByIdProvider(sessionId));

    return Scaffold(
      appBar: AppBar(title: sessionAsync.when(
            data: (s) => Text(s != null ? _formatDate(s.startedAt) : 'Session'),
            loading: () => const Text('Session'),
            error: (_, _) => const Text('Session'),
          )),
      body: climbsAsync.when(
        data: (climbs) {
          if (climbs.isEmpty) {
            return const Center(
              child: Text('No climbs logged', style: TextStyle(color: Colors.grey)),
            );
          }

          final sendCount = climbs.where((c) => c.climb.sent).length;
          final totalCount = climbs.length;

          return Column(
            children: [
              // Summary bar
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(label: 'Total', value: '$totalCount'),
                    _Stat(label: 'Sends', value: '$sendCount', color: Colors.green),
                    _Stat(
                      label: 'Fails',
                      value: '${totalCount - sendCount}',
                      color: Colors.red,
                    ),
                    _Stat(
                      label: 'Send Rate',
                      value: totalCount > 0
                          ? '${(sendCount / totalCount * 100).round()}%'
                          : '—',
                    ),
                  ],
                ),
              ),

              // Climb list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: climbs.length,
                  itemBuilder: (context, index) {
                    final entry = climbs[index];
                    return _ClimbCard(entry: entry);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $hour:$min $amPm';
  }
}

/// Simple provider for a single session by ID.
final sessionByIdProvider =
    FutureProvider.family<Session?, int>((ref, id) async {
  return ref.watch(sessionRepositoryProvider).getById(id);
});

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ClimbCard extends StatelessWidget {
  const _ClimbCard({required this.entry});

  final ClimbWithTags entry;

  @override
  Widget build(BuildContext context) {
    final climb = entry.climb;
    final tags = entry.tags;
    final isSend = climb.sent;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSend ? Colors.green.shade300 : Colors.red.shade300,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grade + send/fail badge
            Row(
              children: [
                Text(
                  '${climb.gradeSystem} ${climb.gradeValue}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Chip(
                  avatar: Icon(
                    isSend ? Icons.check : Icons.close,
                    size: 16,
                    color: isSend ? Colors.green : Colors.red,
                  ),
                  label: Text(
                    isSend ? 'SEND' : 'FAIL',
                    style: TextStyle(
                      color: isSend ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: (isSend ? Colors.green : Colors.red).withAlpha(20),
                  side: BorderSide.none,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Details row
            Row(
              children: [
                _DetailChip(icon: Icons.replay, label: '${climb.attempts} attempt${climb.attempts == 1 ? '' : 's'}'),
                const SizedBox(width: 8),
                if (climb.rpe != null) ...[
                  _DetailChip(icon: Icons.fitness_center, label: 'RPE ${climb.rpe!.round()}'),
                  const SizedBox(width: 8),
                ],
                _DetailChip(
                  icon: Icons.access_time,
                  label: _formatTime(climb.loggedAt),
                ),
              ],
            ),

            // Tags
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((tag) {
                  return Chip(
                    label: Text(tag.name, style: const TextStyle(fontSize: 11)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],

            // Notes
            if (climb.notes != null && climb.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                climb.notes!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
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

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
