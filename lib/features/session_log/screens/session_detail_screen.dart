import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

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
    final userId = Supabase.instance.client.auth.currentUser?.id;
    await repo.log(
      sessionId: widget.sessionId,
      gradeSystem: result.gradeSystem,
      gradeValue: result.gradeValue,
      sent: result.sent,
      attemptNumber: result.attempts,
      problemNumber: 1,
      rpe: result.rpe,
      tagIds: result.tagIds.isNotEmpty ? result.tagIds : null,
      userId: userId,
    );
    ref.invalidate(sessionClimbsProvider(widget.sessionId));
  }

  Future<bool> _showDeleteClimbConfirmation(Climb climb) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Climb'),
            content: Text(
                'Delete this ${climb.sent ? 'SEND' : 'FAIL'} '
                '(${climb.gradeSystem} ${climb.gradeValue})? This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteClimb(int climbId) async {
    final repo = ref.read(climbRepositoryProvider);
    await repo.delete(climbId);
    ref.invalidate(sessionClimbsProvider(widget.sessionId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Climb deleted')),
      );
    }
  }

  Future<void> _editClimb(Climb climb) async {
    final result = await showDialog<_EditClimbResult>(
      context: context,
      builder: (ctx) => _EditClimbDialog(climb: climb),
    );
    if (result == null) return;

    final repo = ref.read(climbRepositoryProvider);
    await repo.update(
      climb.id,
      sent: result.sent,
      attemptNumber: result.attempts,
      rpe: result.rpe,
      completionPercent: result.completionPercent,
      notes: result.notes,
      gradeSystem: result.gradeSystem,
      gradeValue: result.gradeValue,
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
                    return Dismissible(
                      key: Key('climb-${entry.climb.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) async {
                        return await _showDeleteClimbConfirmation(entry.climb);
                      },
                      onDismissed: (_) => _deleteClimb(entry.climb.id),
                      child: _ClimbCard(
                        entry: entry,
                        onTap: () => _editClimb(entry.climb),
                      ),
                    );
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
  const _ClimbCard({required this.entry, this.onTap});

  final ClimbWithTags entry;
  final VoidCallback? onTap;

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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

// ── Edit Climb Dialog ──────────────────────────────────────────────────────

class _EditClimbResult {
  const _EditClimbResult({
    required this.gradeSystem,
    required this.gradeValue,
    required this.sent,
    required this.attempts,
    required this.rpe,
    required this.completionPercent,
    required this.notes,
  });

  final String gradeSystem;
  final String gradeValue;
  final bool sent;
  final int attempts;
  final double? rpe;
  final int? completionPercent;
  final String? notes;
}

class _EditClimbDialog extends StatefulWidget {
  const _EditClimbDialog({required this.climb});

  final Climb climb;

  @override
  State<_EditClimbDialog> createState() => _EditClimbDialogState();
}

class _EditClimbDialogState extends State<_EditClimbDialog> {
  late String _gradeSystem;
  late String _gradeValue;
  late bool _sent;
  late int _attempts;
  late double? _rpe;
  late int? _completionPercent;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _gradeSystem = widget.climb.gradeSystem;
    _gradeValue = widget.climb.gradeValue;
    _sent = widget.climb.sent;
    _attempts = widget.climb.attemptNumber;
    _rpe = widget.climb.rpe;
    _completionPercent = widget.climb.completionPercent;
    _notesController = TextEditingController(text: widget.climb.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Climb'),
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

            // Send / Fail toggle
            SwitchListTile(
              title: Text(_sent ? 'SEND' : 'FAIL'),
              subtitle: const Text('Tap to toggle'),
              value: _sent,
              activeColor: Colors.green,
              inactiveTrackColor: Colors.red.shade200,
              onChanged: (v) => setState(() => _sent = v),
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

            // Completion %
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Completion:'),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _completionPercent?.toDouble() ?? 100,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${_completionPercent ?? 100}%',
                    onChanged: (v) => setState(() => _completionPercent = v.round()),
                  ),
                ),
                Text('${_completionPercent ?? 100}%',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),

            // Notes
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 12),

            // Save / Cancel
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _EditClimbResult(
                    gradeSystem: _gradeSystem,
                    gradeValue: _gradeValue,
                    sent: _sent,
                    attempts: _attempts,
                    rpe: _rpe,
                    completionPercent: _completionPercent,
                    notes: _notesController.text.trim().isEmpty
                        ? null
                        : _notesController.text.trim(),
                  )),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
