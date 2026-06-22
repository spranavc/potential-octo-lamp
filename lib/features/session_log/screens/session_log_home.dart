import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../features/analytics/providers/analytics_providers.dart';
import '../../../features/sync/providers/sync_providers.dart';
import '../../../shared/utils/time_format.dart';
import '../../gyms/providers/gym_providers.dart';
import '../../projects/providers/project_providers.dart';
import '../providers/session_list_provider.dart';
import '../providers/active_session_provider.dart';

class SessionLogHome extends ConsumerWidget {
  const SessionLogHome({super.key});

  Future<void> _refreshFromBoldr(WidgetRef ref) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final syncService = ref.read(syncServiceProvider);
      await syncService.fullSync(userId);
      ref.invalidate(sessionListProvider);
      ref.invalidate(gymListProvider);
      ref.invalidate(projectListProvider);
      ref.invalidate(allClimbsProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLogging = ref.watch(isLoggingProvider);
    final sessionsAsync = ref.watch(sessionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync with Boldr',
            onPressed: () => _refreshFromBoldr(ref),
          ),
          IconButton(
            icon: const Icon(Icons.rocket_launch),
            tooltip: 'Projects',
            onPressed: () => context.go('/session-log/projects'),
          ),
          if (isLogging)
            TextButton.icon(
              onPressed: () => context.go('/session-log/active'),
              icon: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
              label: const Text('Active'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshFromBoldr(ref),
        child: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty && !isLogging) {
            return _EmptyState(onStart: () => context.go('/session-log/active'));
          }
          if (sessions.isEmpty) {
            return const Center(child: Text('No past sessions'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Dismissible(
                key: Key('session-${session.id}'),
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
                confirmDismiss: (_) => _confirmDeleteSession(context, ref, session),
                onDismissed: (_) => _deleteSession(ref, session),
                child: _SessionCard(session: session),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      ),
      floatingActionButton: null,
      bottomNavigationBar: isLogging
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.go('/session-log/projects'),
                        icon: const Icon(Icons.rocket_launch),
                        label: const Text('New Project'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.go('/session-log/active'),
                        icon: const Icon(Icons.add),
                        label: const Text('New Session'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

Future<bool> _confirmDeleteSession(BuildContext context, WidgetRef ref, Session session) async {
  final date = formatDateFull(session.startedAt);
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Session'),
          content: Text('Delete session from $date and all its climbs? This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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

Future<void> _deleteSession(WidgetRef ref, Session session) async {
  final repo = ref.read(sessionRepositoryProvider);
  await repo.delete(session.id);
  try { await Supabase.instance.client.from('sessions').delete().eq('id', session.id); } catch (_) {}
  ref.invalidate(sessionListProvider);
  ref.invalidate(gymSessionsProvider(session.gymId));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_kabaddi, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No sessions yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Tap + to start a new session', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.add),
            label: const Text('Start New Session'),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final startedAt = session.startedAt;
    final date = formatDateFull(startedAt);
    final time = formatTime(startedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.sports_kabaddi),
        title: Text(date),
        subtitle: Text('Started at $time'),
        trailing: session.endedAt != null
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
        onTap: () {
          if (session.endedAt != null) {
            context.go('/session-log/${session.id}');
          } else {
            context.go('/session-log/active');
          }
        },
      ),
    );
  }
}
