import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';

/// Current user's Supabase ID, or null if not signed in.
final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

/// All gyms, ordered by creation date.
final gymListProvider = FutureProvider<List<Gym>>((ref) async {
  final repo = ref.watch(gymRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  return repo.getAll(userId: userId);
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
  final userId = ref.watch(currentUserIdProvider);
  return repo.getByGymId(gymId, userId: userId);
});
