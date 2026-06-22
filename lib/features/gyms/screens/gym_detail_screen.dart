import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../shared/utils/time_format.dart';
import '../../projects/providers/project_providers.dart';
import '../../sync/providers/sync_providers.dart';
import '../providers/gym_providers.dart';

class GymDetailScreen extends ConsumerWidget {
  const GymDetailScreen({super.key, required this.gymId});

  final int gymId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymAsync = ref.watch(gymDetailProvider(gymId));
    final sessionsAsync = ref.watch(gymSessionsProvider(gymId));
    final projectsAsync = ref.watch(_gymProjectsProvider(gymId));

    return gymAsync.when(
      data: (gym) {
        if (gym == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Gym')),
            body: const Center(child: Text('Gym not found')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(gym.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Rename gym',
                onPressed: () => _renameGym(context, ref, gym.name),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete gym',
                onPressed: () => _deleteGym(context, ref, gym.name),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Start session button ─────────────────────────────────
              FilledButton.icon(
                onPressed: () => context.go('/session-log/active'),
                icon: const Icon(Icons.sports_kabaddi),
                label: const Text('Start Session Here'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 16),

              // ── Projects section ──────────────────────────────────────
              const _SectionHeader(title: 'Active Projects'),
              projectsAsync.when(
                data: (projects) {
                  if (projects.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('No active projects at this gym',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: projects
                          .map((p) => _ProjectCard(
                                project: p,
                                onTap: () => context
                                    .push('/session-log/projects/${p.id}'),
                              ))
                          .toList(),
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
                error: (err, _) => Text('Error: $err'),
              ),

              // ── Completed Projects ───────────────────────────────────
              _CompletedProjectsSection(gymId: gymId),

              // ── Recent sessions section ───────────────────────────────
              const _SectionHeader(title: 'Recent Sessions'),
              sessionsAsync.when(
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return const Text('No sessions at this gym yet',
                        style: TextStyle(color: Colors.grey));
                  }
                  return Column(
                    children: sessions.take(10).map((s) {
                      final date = formatDateFull(s.startedAt);
                      final time = formatTime(s.startedAt);
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.sports_kabaddi, size: 20),
                        title: Text(date),
                        subtitle: Text(
                          s.endedAt != null ? 'Completed · Started $time' : 'In progress · Started $time',
                          style: TextStyle(
                            color: s.endedAt != null ? Colors.green : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => context.go('/session-log/${s.id}'),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
                error: (err, _) => Text('Error: $err'),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Gym')),
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  Future<void> _renameGym(BuildContext context, WidgetRef ref, String currentName) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: currentName);
        return AlertDialog(
          title: const Text('Rename Gym'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Gym name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
    if (name != null && name.trim().isNotEmpty) {
      final repo = ref.read(gymRepositoryProvider);
      await repo.updateName(gymId, name.trim());
      ref.invalidate(gymDetailProvider(gymId));
      ref.invalidate(gymListProvider);
      triggerPushSync(ref);
    }
  }

  Future<void> _deleteGym(BuildContext context, WidgetRef ref, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Gym'),
        content: Text('Delete "$name" and all its data?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(gymRepositoryProvider);
      await repo.delete(gymId);
      ref.invalidate(gymListProvider);
      if (context.mounted) context.go('/gyms');
    }
  }

}
/// Filters projects to those at this gym that are completed.
final _gymCompletedProjectsProvider =
    FutureProvider.family<List<Project>, int>((ref, gymId) async {
  final projects = await ref.watch(projectListProvider.future);
  return projects.where((p) => p.gymId == gymId && p.status == 'completed').toList();
});

class _CompletedProjectsSection extends ConsumerWidget {
  const _CompletedProjectsSection({required this.gymId});

  final int gymId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedAsync = ref.watch(_gymCompletedProjectsProvider(gymId));

    return completedAsync.when(
      data: (projects) {
        if (projects.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Completed Projects'),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: projects
                    .map((p) => _ProjectCard(
                          project: p,
                          onTap: () => context
                              .push('/session-log/projects/${p.id}'),
                        ))
                    .toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Filters projects to those at this gym with status 'active'.
final _gymProjectsProvider =
    FutureProvider.family<List<Project>, int>((ref, gymId) async {
  final projects = await ref.watch(projectListProvider.future);
  return projects.where((p) => p.gymId == gymId && p.status == 'active').toList();
});

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(projectProgressProvider(project.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rocket_launch, size: 20, color: Colors.deepOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${project.gradeSystem} ${project.gradeValue}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              progressAsync.when(
                data: (progress) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.sendRate,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
                loading: () => const SizedBox(height: 6),
                error: (_, __) => const SizedBox(height: 6),
              ),
              const SizedBox(height: 4),
              progressAsync.when(
                data: (progress) => Text(
                  '${progress.sentClimbs} / ${progress.totalClimbs} sends',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
