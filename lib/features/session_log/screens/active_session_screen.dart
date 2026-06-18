import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    // If no active session, start one with a default gym
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(activeSessionProvider);
      if (!state.isActive) {
        _startDefaultSession();
      }
    });
  }

  Future<void> _startDefaultSession() async {
    // Auto-create a default gym for the session if none exists
    // For now, gymId=0 signals "unassigned" — Phase 3 will fix this properly
    try {
      await ref.read(activeSessionProvider.notifier).start(gymId: 1);
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
        : _selectedTagIds.join(', '); // Simplified — real names via provider lookup

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
