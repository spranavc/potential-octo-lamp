import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';
import '../providers/gym_providers.dart';

class GymDetailScreen extends ConsumerWidget {
  const GymDetailScreen({super.key, required this.gymId});

  final int gymId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymAsync = ref.watch(gymDetailProvider(gymId));
    final wallsAsync = ref.watch(gymWallsProvider(gymId));
    final colorsAsync = ref.watch(gymColorsProvider(gymId));
    final sessionsAsync = ref.watch(gymSessionsProvider(gymId));

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
              // ── Walls section ────────────────────────────────────────
              _SectionHeader(
                title: 'Walls',
                trailing: TextButton.icon(
                  onPressed: () => _addWall(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ),
              wallsAsync.when(
                data: (walls) {
                  if (walls.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('No walls added yet', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Column(
                    children: walls
                        .map((w) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.terrain),
                              title: Text(w.name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _renameWall(context, ref, w),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () => _deleteWall(ref, w.id),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
                error: (err, _) => Text('Error: $err'),
              ),

              // ── Colors section ───────────────────────────────────────
              _SectionHeader(
                title: 'Color Decoder',
                trailing: TextButton.icon(
                  onPressed: () => context.go('/gyms/$gymId/colors'),
                  icon: const Icon(Icons.palette, size: 18),
                  label: const Text('Configure'),
                ),
              ),
              colorsAsync.when(
                data: (colors) {
                  if (colors.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('No colors configured', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: colors
                          .map((c) => Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: _parseHex(c.colorHex),
                                  radius: 10,
                                ),
                                label: Text('${c.colorName} = ${c.gradeValue}'),
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
                      final date =
                          '${s.startedAt.month}/${s.startedAt.day}/${s.startedAt.year}';
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.sports_kabaddi, size: 20),
                        title: Text(date),
                        subtitle: Text(
                          s.endedAt != null ? 'Completed' : 'In progress',
                          style: TextStyle(
                            color: s.endedAt != null ? Colors.green : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
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

  Future<void> _addWall(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Wall'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Wall name (e.g. "Main Cave")',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    if (name != null && name.trim().isNotEmpty) {
      final repo = ref.read(gymRepositoryProvider);
      await repo.addWall(gymId, name.trim());
      ref.invalidate(gymWallsProvider(gymId));
    }
  }

  Future<void> _renameWall(BuildContext context, WidgetRef ref, Wall wall) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: wall.name);
        return AlertDialog(
          title: const Text('Rename Wall'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Wall name',
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
    if (name != null && name.trim().isNotEmpty && name.trim() != wall.name) {
      final repo = ref.read(gymRepositoryProvider);
      await repo.renameWall(wall.id, name.trim());
      ref.invalidate(gymWallsProvider(gymId));
    }
  }

  Future<void> _deleteWall(WidgetRef ref, int wallId) async {
    final repo = ref.read(gymRepositoryProvider);
    await repo.deleteWall(wallId);
    ref.invalidate(gymWallsProvider(gymId));
  }
}

Color _parseHex(String hex) {
  final value = hex.replaceFirst('#', '');
  if (value.length == 6) {
    return Color(int.parse('FF$value', radix: 16));
  }
  return Colors.grey;
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
