import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/database/database.dart';
import '../providers/session_list_provider.dart';
import '../providers/active_session_provider.dart';

class SessionLogHome extends ConsumerWidget {
  const SessionLogHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLogging = ref.watch(isLoggingProvider);
    final sessionsAsync = ref.watch(sessionListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Log'),
        actions: [
          if (isLogging)
            TextButton.icon(
              onPressed: () => context.go('/session-log/active'),
              icon: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
              label: const Text('Active'),
            ),
        ],
      ),
      body: sessionsAsync.when(
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
              return _SessionCard(session: session);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: isLogging
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/session-log/active'),
              icon: const Icon(Icons.add),
              label: const Text('New Session'),
            ),
    );
  }
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
    final date = '${startedAt.month}/${startedAt.day}/${startedAt.year}';
    final time = '${startedAt.hour}:${startedAt.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.sports_kabaddi),
        title: Text(date),
        subtitle: Text('Started at $time'),
        trailing: session.endedAt != null
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
        onTap: () => context.go('/session-log/${session.id}'),
      ),
    );
  }
}
