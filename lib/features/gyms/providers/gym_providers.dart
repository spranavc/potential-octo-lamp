import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';

/// Current user's Supabase ID, or null if not signed in.
final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

/// User-created and user-added gyms.
///
/// Returns gyms where [Gym.isDirectory] is false OR [Gym.userId] is non-null --
/// i.e., gyms the user created or imported from the directory.  Directory-only
/// gyms (isDirectory = true, userId = null) are excluded.
final gymListProvider = FutureProvider<List<Gym>>((ref) async {
  final repo = ref.watch(gymRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  final all = await repo.getAll(userId: userId);
  return all.where((g) => !g.isDirectory || g.userId != null).toList();
});

/// Directory gyms — fetched from the Supabase directory_gyms table.
///
/// These are publicly readable DMV-area climbing gyms curated by the app.
final directoryGymsProvider = FutureProvider<List<Gym>>((ref) async {
  try {
    final data = await Supabase.instance.client
        .from('directory_gyms')
        .select()
        .order('name') as List<dynamic>;
    final now = DateTime.now();
    return data.map((row) {
      final m = Map<String, dynamic>.from(row as Map);
      return Gym(
        id: m['id'] as int,
        name: m['name'] as String,
        userId: null,
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        address: m['address'] as String?,
        phone: m['phone'] as String?,
        website: m['website'] as String?,
        description: m['description'] as String?,
        photoUrl: m['photo_url'] as String?,
        rating: (m['rating'] as num?)?.toDouble(),
        ratingCount: m['rating_count'] as int?,
        hours: m['hours'] as String?,
        dayPassPrice: m['day_pass_price'] as String?,
        hasBouldering: m['has_bouldering'] as bool?,
        hasTopRope: m['has_top_rope'] as bool?,
        hasLead: m['has_lead'] as bool?,
        hasAutoBelay: m['has_auto_belay'] as bool?,
        hasTrainingArea: m['has_training_area'] as bool?,
        hasYoga: m['has_yoga'] as bool?,
        hasProShop: m['has_pro_shop'] as bool?,
        hasCafe: m['has_cafe'] as bool?,
        hasShowers: m['has_showers'] as bool?,
        hasParking: m['has_parking'] as bool?,
        isDirectory: true,
        syncStatus: 'synced',
        createdAt: now,
        updatedAt: null,
      );
    }).toList();
  } catch (_) {
    return [];
  }
});

/// Gyms that belong to the current user.
///
/// Returns gyms where [Gym.userId] equals the current Supabase user ID.
/// These are gyms the user created or imported from the directory.
final myGymsProvider = FutureProvider<List<Gym>>((ref) async {
  final repo = ref.watch(gymRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
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
