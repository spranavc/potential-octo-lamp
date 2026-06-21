import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/providers/repository_providers.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_card.dart';

class GymsListScreen extends ConsumerWidget {
  const GymsListScreen({super.key});

  Future<void> _addGym(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _AddGymDialog(),
    );
    if (name != null && name.trim().isNotEmpty) {
      final repo = ref.read(gymRepositoryProvider);
      await repo.create(name.trim());
      ref.invalidate(gymListProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymsAsync = ref.watch(gymListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gyms')),
      body: gymsAsync.when(
        data: (gyms) {
          if (gyms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fitness_center, size: 72, color: Colors.grey),
                    const SizedBox(height: 20),
                    const Text(
                      'Welcome to ClimbApp!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Start by adding your gym below.\nThen you can log sessions, track progress,\nand discover your climbing patterns.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => _addGym(context, ref),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Your First Gym'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: gyms.length,
            itemBuilder: (context, index) {
              final gym = gyms[index];
              return Dismissible(
                key: ValueKey(gym.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  // Don't dismiss yet — we show a dialog first
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Gym'),
                      content: Text(
                        'Delete "${gym.name}" and all its sessions, walls, and colors?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    final repo = ref.read(gymRepositoryProvider);
                    await repo.delete(gym.id);
                    ref.invalidate(gymListProvider);
                  }
                  return false; // We handle deletion ourselves
                },
                child: GymCard(
                  gym: gym,
                  onTap: () => context.go('/gyms/${gym.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-gym',
        onPressed: () => _addGym(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Gym'),
      ),
    );
  }
}

class _AddGymDialog extends StatelessWidget {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Gym'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Gym name',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
