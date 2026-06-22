import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';
import '../../analytics/providers/analytics_providers.dart';
import '../../gyms/providers/gym_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../../sync/providers/sync_providers.dart';
import '../providers/active_session_provider.dart';
import '../providers/session_list_provider.dart';
import '../widgets/swipe_card.dart';
import '../widgets/grade_picker.dart';
import '../widgets/tag_chips.dart';
import '../widgets/rpe_slider.dart';
import 'project_picker_dialog.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  // Current climb being configured
  String _gradeSystem = 'V-scale';
  String _gradeValue = 'VB';
  List<int> _selectedTagIds = [];
  double? _rpe;
  int? _completionPercent;
  String? _climbNotes;
  List<int> _selectedProjectIds = [];
  bool _hasAttemptedCurrentProblem = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureSessionStarted();
    });
  }

  Future<void> _ensureSessionStarted() async {
    final sessionState = ref.read(activeSessionProvider);
    if (sessionState.isActive) return;

    final gyms = await ref.read(gymListProvider.future);

    if (gyms.isEmpty) {
      if (!mounted) return;
      final create = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Gyms'),
          content: const Text(
            'You need to add a gym before starting a session.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Add Gym'),
            ),
          ],
        ),
      );
      if (create == true && mounted) {
        context.go('/gyms');
      } else if (mounted) {
        // User cancelled — go back to session log
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/session-log');
        });
      }
      return;
    }

    if (!mounted) return;

    final int gymId;
    if (gyms.length == 1) {
      gymId = gyms.first.id;
    } else {
      // Multiple gyms — let user pick
      gymId = await showDialog<int>(
            context: context,
            builder: (ctx) => _GymPickerDialog(gyms: gyms),
          ) ??
          -1;
      if (gymId == -1) {
        context.go('/session-log');
        return;
      }
    }

    if (!mounted) return;
    try {
      await ref.read(activeSessionProvider.notifier).start(gymId: gymId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start session: $e')),
        );
      }
    }
  }

  Future<void> _logSend() async {
    _hasAttemptedCurrentProblem = true;
    // If completion < 100%, confirm with user
    if (_completionPercent != null && _completionPercent! < 100) {
      if (!mounted) return;
      final adjusted = await showDialog<int?>(
        context: context,
        builder: (ctx) => _CompletionConfirmDialog(
          currentPercent: _completionPercent!,
        ),
      );
      if (adjusted == null) return; // user cancelled
      if (adjusted == 100) {
        setState(() => _completionPercent = 100);
      }
    }

    await ref.read(activeSessionProvider.notifier).logAttempt(
          gradeSystem: _gradeSystem,
          gradeValue: _gradeValue,
          sent: true,
          rpe: _rpe,
          completionPercent: _completionPercent ?? 100,
          notes: _climbNotes?.trim().isEmpty == true ? null : _climbNotes?.trim(),
          tagIds: _selectedTagIds.isNotEmpty ? _selectedTagIds : null,
        );
    _invalidateProjectProgress();
    _resetTags();

    if (mounted) {
      _showPostSendDialog();
    }
  }

  Future<void> _logFail() async {
    _hasAttemptedCurrentProblem = true;
    await ref.read(activeSessionProvider.notifier).logAttempt(
          gradeSystem: _gradeSystem,
          gradeValue: _gradeValue,
          sent: false,
          rpe: _rpe,
          completionPercent: _completionPercent,
          notes: _climbNotes?.trim().isEmpty == true ? null : _climbNotes?.trim(),
          tagIds: _selectedTagIds.isNotEmpty ? _selectedTagIds : null,
        );
    _invalidateProjectProgress();
    _resetTags();
    ref.read(activeSessionProvider.notifier).nextAttempt();
  }

  void _skipToNextProblem() async {
    if (!mounted) return;
    if (!_hasAttemptedCurrentProblem) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Attempts Yet'),
          content: const Text(
            'You haven\'t made any attempts on this problem. '
            'The climb will not be recorded. Skip anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Skip'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    ref.read(activeSessionProvider.notifier).nextProblem();
    _hasAttemptedCurrentProblem = false;
    _resetTags();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skipped to Problem #${ref.read(activeSessionProvider).currentProblemNumber}',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _resetTags() {
    setState(() {
      _selectedTagIds = [];
      _rpe = null;
      _completionPercent = null;
      _climbNotes = null;
    });
  }

  void _invalidateProjectProgress() {
    for (final projectId in _selectedProjectIds) {
      ref.invalidate(projectClimbsProvider(projectId));
      ref.invalidate(projectProgressProvider(projectId));
    }
  }

  Future<void> _showPostSendDialog() async {
    final projectIds = _selectedProjectIds;
    final hasProject = projectIds.isNotEmpty;

    String? projectName;
    if (hasProject) {
      final projects = await ref.read(projectListProvider.future);
      projectName = projects.where((p) => projectIds.contains(p.id)).firstOrNull?.name;
    }

    if (!mounted) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (projectName != null)
                Text(
                  '💪 Sent on "$projectName"!',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  '🎉 Problem sent!',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              if (projectName != null)
                Text(
                  'Great progress on "$projectName"!',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  ref.read(activeSessionProvider.notifier).nextProblem();
                  Navigator.pop(ctx, 'next');
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next Problem'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(activeSessionProvider.notifier).resumeProblem();
                  Navigator.pop(ctx, 'retry');
                },
                icon: const Icon(Icons.replay),
                label: const Text('Retry This Problem'),
              ),
              if (projectName != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx, 'complete');
                    _showCompleteProjectDialog(projectName!);
                  },
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('Mark Project Complete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCompleteProjectDialog(String projectName) async {
    final projectId = _selectedProjectIds.first;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Project?'),
        content: Text('Mark "$projectName" as completed? Congratulations! 🎉'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete!'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(projectRepositoryProvider);
      await repo.markCompleted(projectId);
      ref.invalidate(projectDetailProvider(projectId));
      ref.invalidate(projectProgressProvider(projectId));
      ref.invalidate(projectListProvider);

      // Clear the completed project from the active session
      setState(() {
        _selectedProjectIds.remove(projectId);
      });
      ref.read(activeSessionProvider.notifier).setProjects(
            List<int>.from(_selectedProjectIds),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🎉 "$projectName" completed! Ready for a new challenge.')),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedTagIds = [];
      _rpe = null;
      _completionPercent = null;
      _climbNotes = null;
    });
  }

  Future<void> _endSession() async {
    final state = ref.read(activeSessionProvider);
    if (state.totalCount == 0) {
      // No climbs logged — just cancel and delete the empty session
      await ref.read(activeSessionProvider.notifier).cancel();
    } else {
      await ref.read(activeSessionProvider.notifier).end();
    }
    ref.invalidate(sessionListProvider);
    ref.invalidate(gymSessionsProvider(state.gymId));
    ref.invalidate(allClimbsProvider);
    // Push pending changes to Supabase in the background
    triggerPushSync(ref);
    if (mounted) context.go('/session-log');
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(activeSessionProvider);
    final tagLabelsAsync = ref.watch(_tagLabelsProvider(_selectedTagIds));
    final projectNameStr = _selectedProjectIds.isNotEmpty
        ? _selectedProjectIds.join(',')
        : '';
    final projectNameAsync = ref.watch(_projectNamesProvider(projectNameStr));
    final gymAsync = ref.watch(gymDetailProvider(sessionState.gymId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endSession();
      },
      child: Scaffold(
        appBar: AppBar(
          title: gymAsync.when(
            data: (gym) => Text(gym != null ? '${gym.name}' : 'Logging Session'),
            loading: () => const Text('Logging Session'),
            error: (_, __) => const Text('Logging Session'),
          ),
          actions: [
            TextButton(
              onPressed: () => _endSession(),
              child: const Text('End Session'),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),

                // Project chip above the card
                _ProjectChip(
                  projectName: projectNameAsync.valueOrNull,
                  onTap: () => _showProjectPicker(),
                ),

                const SizedBox(height: 12),

                // Problem / attempt indicator
                Text(
                  'Problem #${sessionState.currentProblemNumber} · Attempt #${sessionState.currentAttemptNumber}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),

                // The swipe card
                SwipeCard(
                  gradeSystem: _gradeSystem,
                  gradeValue: _gradeValue,
                  selectedTagIds: _selectedTagIds,
                  attempts: sessionState.currentAttemptNumber,
                  rpe: _rpe,
                  tagLabels: tagLabelsAsync.valueOrNull ?? '',
                  projectName: projectNameAsync.valueOrNull,
                  onSend: _logSend,
                  onFail: _logFail,
                  onEditGrade: () {
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

                const SizedBox(height: 16),

                // Controls below the card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Tags
                      TagChips(
                        selectedIds: _selectedTagIds,
                        onChanged: (ids) => setState(() => _selectedTagIds = ids),
                      ),
                      const SizedBox(height: 16),

                      // RPE slider
                      RpeSlider(
                        value: _rpe,
                        onChanged: (v) => setState(() => _rpe = v),
                      ),

                      // Completion %
                      const SizedBox(height: 12),
                      _CompletionSlider(
                        value: _completionPercent,
                        onChanged: (v) => setState(() => _completionPercent = v),
                      ),

                      // Quick notes
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Quick notes (optional)...',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        onChanged: (v) => _climbNotes = v,
                        controller: TextEditingController(text: _climbNotes),
                      ),

                      const SizedBox(height: 16),

                      // Skip to next problem
                      OutlinedButton.icon(
                        onPressed: _skipToNextProblem,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Skip to Next Problem'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Recent climbs in this session
                if (sessionState.climbs.isNotEmpty)
                  _RecentClimbsList(climbs: sessionState.climbs),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showProjectPicker() async {
    final gymId = ref.read(activeSessionProvider).gymId;
    final projectRepo = ref.read(projectRepositoryProvider);

    final selectedIds = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => ProjectPickerDialog(
        gymId: gymId,
        projectRepository: projectRepo,
        initialSelectedIds: _selectedProjectIds,
        userId: Supabase.instance.client.auth.currentUser?.id,
      ),
    );

    if (selectedIds == null) return;

    setState(() => _selectedProjectIds = selectedIds);
    ref
        .read(activeSessionProvider.notifier)
        .setProjects(selectedIds);

    // Auto-set grade from the first selected project
    if (selectedIds.isNotEmpty) {
      final projects = await ref.read(projectListProvider.future);
      final firstProject = projects.where((p) => selectedIds.contains(p.id)).firstOrNull;
      if (firstProject != null && mounted) {
        setState(() {
          _gradeSystem = firstProject.gradeSystem;
          _gradeValue = firstProject.gradeValue;
        });
      }
    }
  }
}

/// Dialog to choose which gym to log a session at.
class _GymPickerDialog extends StatelessWidget {
  const _GymPickerDialog({required this.gyms});

  final List<Gym> gyms;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Gym'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: gyms.length,
          itemBuilder: (context, index) {
            final gym = gyms[index];
            return ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(gym.name),
              onTap: () => Navigator.of(context).pop(gym.id),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(-1),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Displays a send/fail counter badge.
class SessionCounter extends StatelessWidget {
  const SessionCounter({
    super.key,
    required this.sendCount,
    required this.failCount,
    required this.child,
  });

  final int sendCount;
  final int failCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 8,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CounterBadge(label: '$sendCount', icon: Icons.check, color: Colors.green),
              const SizedBox(width: 8),
              _CounterBadge(label: '$failCount', icon: Icons.close, color: Colors.red),
            ],
          ),
        ),
      ],
    );
  }
}

class _CounterBadge extends StatelessWidget {
  const _CounterBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      backgroundColor: color.withAlpha(20),
      side: BorderSide.none,
    );
  }
}

/// Resolves tag IDs to a comma-separated label string for display.
final _tagLabelsProvider = FutureProvider.family<String, List<int>>((ref, tagIds) async {
  if (tagIds.isEmpty) return '';
  final tags = await ref.watch(tagRepositoryProvider).getAll();
  final tagMap = {for (final t in tags) t.id: t.name};
  return tagIds.map((id) => tagMap[id] ?? '$id').join(', ');
});

/// Resolves project IDs to their names by fetching all projects and filtering.
final _projectNamesProvider =
    FutureProvider.family<String?, String>((ref, idList) async {
  if (idList.isEmpty) return null;
  final projectIds = idList.split(',').map(int.parse).toList();
  final allProjects = await ref.watch(projectListProvider.future);
  final names = <String>[];
  for (final project in allProjects) {
    if (projectIds.contains(project.id)) {
      names.add(project.name);
    }
  }
  return names.isEmpty ? null : names.join(', ');
});

/// A small chip that shows the selected project name, or "No project".
/// Tapping opens the project picker dialog.
class _ProjectChip extends StatelessWidget {
  const _ProjectChip({required this.projectName, required this.onTap});

  final String? projectName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        projectName != null ? Icons.rocket_launch : Icons.rocket_launch_outlined,
        size: 18,
      ),
      label: Text(projectName ?? '+ Add to project'),
      onPressed: onTap,
    );
  }
}

// ── Completion Confirm Dialog ────────────────────────────────────────────────

class _CompletionConfirmDialog extends StatefulWidget {
  const _CompletionConfirmDialog({required this.currentPercent});

  final int currentPercent;

  @override
  State<_CompletionConfirmDialog> createState() =>
      _CompletionConfirmDialogState();
}

class _CompletionConfirmDialogState extends State<_CompletionConfirmDialog> {
  late double _percent;

  @override
  void initState() {
    super.initState();
    _percent = widget.currentPercent.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Send'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You marked this as ${widget.currentPercent}% completed. '
            'Did you actually send it?',
          ),
          const SizedBox(height: 16),
          Text(
            'Completion: ${_percent.round()}%',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Slider(
            value: _percent,
            min: 0,
            max: 100,
            divisions: 20,
            onChanged: (v) => setState(() => _percent = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _percent.round()),
          child: Text(_percent.round() == 100
              ? 'Yes, I sent it!'
              : 'Save (${_percent.round()}%)'),
        ),
      ],
    );
  }
}

// ── Completion % Slider ─────────────────────────────────────────────────────

class _CompletionSlider extends StatelessWidget {
  const _CompletionSlider({required this.value, required this.onChanged});

  final int? value;
  final void Function(int? newValue) onChanged;

  @override
  Widget build(BuildContext context) {
    final displayValue = value ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              displayValue > 0 ? 'Completed: $displayValue%' : 'Completion %',
              style: displayValue > 0
                  ? Theme.of(context).textTheme.titleSmall
                  : const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        Slider(
          value: (value ?? 0).toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          label: value == null || value == 0 ? null : '$displayValue%',
          onChanged: (v) {
            if (v == 0) {
              onChanged(null);
            } else {
              onChanged(v.round());
            }
          },
        ),
      ],
    );
  }
}

// ── Recent Climbs List ──────────────────────────────────────────────────────

class _RecentClimbsList extends StatelessWidget {
  const _RecentClimbsList({required this.climbs});

  final List<LoggedClimb> climbs;

  @override
  Widget build(BuildContext context) {
    final recent = climbs.length > 10 ? climbs.sublist(climbs.length - 10) : climbs;
    final reversed = recent.reversed.toList();

    return SizedBox(
      height: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 4),
            child: Text(
              'Recent climbs',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: reversed.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final climb = reversed[index];
                final isSend = climb.sent;
                return InkWell(
                  onTap: () => _ClimbDetailSheet.show(
                    context,
                    climb: climb,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isSend ? Colors.green : Colors.red).withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isSend ? Colors.green : Colors.red).withAlpha(60),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSend ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: isSend ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${climb.gradeSystem} ${climb.gradeValue}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pr ${climb.problemNumber} · At ${climb.attemptNumber}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const Spacer(),
                        if (climb.rpe != null)
                          Text(
                            'RPE ${climb.rpe!.round()}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Climb Detail Bottom Sheet ───────────────────────────────────────────────

class _ClimbDetailSheet extends StatelessWidget {
  const _ClimbDetailSheet({required this.climb});

  final LoggedClimb climb;

  static void show(BuildContext context, {required LoggedClimb climb}) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _ClimbDetailSheet(climb: climb),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSend = climb.sent;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${climb.gradeSystem} ${climb.gradeValue}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Chip(
                  avatar: Icon(
                    isSend ? Icons.check : Icons.close,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    isSend ? 'SEND' : 'FAIL',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: isSend ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow('Problem', '#${climb.problemNumber}'),
            _detailRow('Attempt', '#${climb.attemptNumber}'),
            if (climb.rpe != null)
              _detailRow('RPE', '${climb.rpe!.round()} / 10'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
