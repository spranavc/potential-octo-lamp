import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/database/database.dart';
import '../../gyms/providers/gym_providers.dart';
import '../providers/active_session_provider.dart';
import '../widgets/swipe_card.dart';
import '../widgets/grade_picker.dart';
import '../widgets/tag_chips.dart';
import '../widgets/attempts_counter.dart';
import '../widgets/rpe_slider.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  // Current climb being configured
  String _gradeSystem = 'V-scale';
  String _gradeValue = 'V0';
  List<int> _selectedTagIds = [];
  int _attempts = 1;
  double? _rpe;

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
      // No gyms — this shouldn't happen since we auto-create a default in Phase 0
      // but guard anyway
      if (!mounted) return;
      final create = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Gyms'),
          content: const Text('You need a gym before starting a session. Create one now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Create Gym'),
            ),
          ],
        ),
      );
      if (create == true) {
        context.go('/gyms');
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

  void _logSend() {
    ref.read(activeSessionProvider.notifier).logClimb(
          gradeSystem: _gradeSystem,
          gradeValue: _gradeValue,
          sent: true,
          attempts: _attempts,
          rpe: _rpe,
          tagIds: _selectedTagIds.isNotEmpty ? _selectedTagIds : null,
        );
    _resetForm();
  }

  void _logFail() {
    ref.read(activeSessionProvider.notifier).logClimb(
          gradeSystem: _gradeSystem,
          gradeValue: _gradeValue,
          sent: false,
          attempts: _attempts,
          rpe: _rpe,
          tagIds: _selectedTagIds.isNotEmpty ? _selectedTagIds : null,
        );
    _resetForm();
  }

  void _resetForm() {
    setState(() {
      _selectedTagIds = [];
      _attempts = 1;
      _rpe = null;
    });
  }

  void _endSession() {
    ref.read(activeSessionProvider.notifier).end();
    context.go('/session-log');
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(activeSessionProvider);
    final tagNames = _selectedTagIds.isEmpty
        ? ''
        : _selectedTagIds.join(', ');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/session-log');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Logging Session'),
          actions: [
            TextButton(
              onPressed: _endSession,
              child: const Text('End Session'),
            ),
          ],
        ),
        body: SafeArea(
          child: SessionCounter(
            sendCount: sessionState.sendCount,
            failCount: sessionState.failCount,
            child: Column(
              children: [
                const Spacer(),

                // The swipe card
                SwipeCard(
                  gradeSystem: _gradeSystem,
                  gradeValue: _gradeValue,
                  selectedTagIds: _selectedTagIds,
                  attempts: _attempts,
                  rpe: _rpe,
                  tagLabels: tagNames,
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

                      // Attempts and RPE row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Expanded(
                            child: AttemptsCounter(
                              value: _attempts,
                              onChanged: (v) => setState(() => _attempts = v),
                            ),
                          ),
                          Expanded(
                            child: RpeSlider(
                              value: _rpe,
                              onChanged: (v) => setState(() => _rpe = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
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
