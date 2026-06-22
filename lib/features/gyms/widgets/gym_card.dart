import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../projects/providers/project_providers.dart';

class GymCard extends ConsumerWidget {
  const GymCard({super.key, required this.gym, this.onTap});

  final Gym gym;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectCountAsync = ref.watch(_gymProjectCountProvider(gym.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.fitness_center, size: 28),
        title: Text(gym.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: projectCountAsync.when(
          data: (count) {
            final parts = <String>[];
            parts.add('Tap to view details');
            if (count > 0) {
              parts.add('$count active project${count == 1 ? '' : 's'}');
            }
            return Text(parts.join(' · '));
          },
          loading: () => const Text('Tap to view details'),
          error: (_, __) => const Text('Tap to view details'),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

/// Counts active projects at a gym.
final _gymProjectCountProvider =
    FutureProvider.family<int, int>((ref, gymId) async {
  final projects = await ref.watch(projectListProvider.future);
  return projects.where((p) => p.gymId == gymId && p.status == 'active').length;
});
