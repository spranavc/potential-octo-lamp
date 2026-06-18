import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';

/// All gyms, ordered by creation date.
final gymListProvider = FutureProvider<List<Gym>>((ref) async {
  final repo = ref.watch(gymRepositoryProvider);
  return repo.getAll();
});

/// A single gym by id.
final gymDetailProvider =
    FutureProvider.family<Gym?, int>((ref, gymId) async {
  final repo = ref.watch(gymRepositoryProvider);
  return repo.getById(gymId);
});

/// Walls for a specific gym.
final gymWallsProvider =
    FutureProvider.family<List<Wall>, int>((ref, gymId) async {
  final repo = ref.watch(gymRepositoryProvider);
  return repo.getWalls(gymId);
});

/// Recent sessions at a specific gym.
final gymSessionsProvider =
    FutureProvider.family<List<Session>, int>((ref, gymId) async {
  final repo = ref.watch(sessionRepositoryProvider);
  return repo.getByGymId(gymId);
});
