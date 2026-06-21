import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../shared/utils/time_format.dart';
import '../providers/session_detail_provider.dart';
import '../widgets/grade_picker.dart';
import '../widgets/tag_chips.dart';
import '../widgets/attempts_counter.dart';
import '../widgets/rpe_slider.dart';

class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  Future<void> _logRetroactiveClimb() async {
    final result = await showDialog<_RetroClimbResult>(
      context: context,
      builder: (ctx) => _RetroClimbDialog(),
    );
    if (result == null) return;

    final repo = ref.read(climbRepositoryProvider);
    await repo.log(
      sessionId: widget.sessionId,
      gradeSystem: result.gradeSystem,
      gradeValue: result.gradeValue,
      sent: result.sent,
      attemptNumber: result.attempts,
      problemNumber: 1,
      rpe: result.rpe,
      tagIds: result.tagIds.isNotEmpty ? result.tagIds : null,
    );
    ref.invalidate(sessionClimbsProvider(widget.sessionId));
  }

  @override
  Widget build(BuildContext context) {
    final climbsAsync = ref.watch(sessionClimbsProvider(widget.sessionId));
    final sessionAsync = ref.watch(sessionByIdProvider(widget.sessionId));

    return Scaffold(
      appBar: AppBar(title: sessionAsync.when(
            data: (s) => Text(s != null ? _formatDate(s.startedAt) : 'Session'),
            loading: () => const Text('Session'),
            error: (_, _) => const Text('Session'),
          )),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'log-climb',
        onPressed: _logRetroactiveClimb,
        icon: const Icon(Icons.add),
        label: const Text('Log Climb'),
      ),
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

  String _formatDate(DateTime dt) => formatDateTime(dt);
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
                _DetailChip(icon: Icons.replay, label: 'Problem #${climb.problemNumber} · Att #${climb.attemptNumber}'),
                const SizedBox(width: 8),
                if (climb.rpe != null) ...[
                  _DetailChip(icon: Icons.fitness_center, label: 'RPE ${climb.rpe!.round()}'),
                  const SizedBox(width: 8),
                ],
                _DetailChip(
                  icon: Icons.access_time,
                  label: formatTime(climb.loggedAt),
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

            // Linked projects
            if (entry.projects.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: entry.projects.map((project) {
                  return ActionChip(
                    avatar: const Icon(Icons.rocket_launch, size: 14),
                    label: Text(project.name, style: const TextStyle(fontSize: 11)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => context.push(
                      '/session-log/projects/${project.id}',
                    ),
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

// ── Retroactive Climb Dialog ────────────────────────────────────────────────

class _RetroClimbResult {
  const _RetroClimbResult({
    required this.gradeSystem,
    required this.gradeValue,
    required this.sent,
    required this.attempts,
    required this.rpe,
    required this.tagIds,
  });

  final String gradeSystem;
  final String gradeValue;
  final bool sent;
  final int attempts;
  final double? rpe;
  final List<int> tagIds;
}

class _RetroClimbDialog extends StatefulWidget {
  @override
  State<_RetroClimbDialog> createState() => _RetroClimbDialogState();
}

class _RetroClimbDialogState extends State<_RetroClimbDialog> {
  String _gradeSystem = 'V-scale';
  String _gradeValue = 'V0';
  List<int> _selectedTagIds = [];
  int _attempts = 1;
  double? _rpe;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log Climb'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grade
            ListTile(
              title: Text('$_gradeSystem $_gradeValue'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                GradePicker.show(
                  context,
                  onSelected: (system, value) {
                    setState(() {
                      _gradeSystem = system;
                      _gradeValue = value;
                    });
                  },
                  initialSystem: _gradeSystem,
                  initialValue: _gradeValue,
                );
              },
            ),

            // Attempts
            AttemptsCounter(
              value: _attempts,
              onChanged: (v) => setState(() => _attempts = v),
            ),

            // RPE
            RpeSlider(
              value: _rpe,
              onChanged: (v) => setState(() => _rpe = v),
            ),

            const SizedBox(height: 12),

            // Tags
            TagChips(
              selectedIds: _selectedTagIds,
              onChanged: (ids) => setState(() => _selectedTagIds = ids),
            ),

            const SizedBox(height: 12),

            // Send / Fail buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, _RetroClimbResult(
                      gradeSystem: _gradeSystem,
                      gradeValue: _gradeValue,
                      sent: false,
                      attempts: _attempts,
                      rpe: _rpe,
                      tagIds: _selectedTagIds,
                    )),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Fail'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _RetroClimbResult(
                      gradeSystem: _gradeSystem,
                      gradeValue: _gradeValue,
                      sent: true,
                      attempts: _attempts,
                      rpe: _rpe,
                      tagIds: _selectedTagIds,
                    )),
                    icon: const Icon(Icons.check),
                    label: const Text('Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
