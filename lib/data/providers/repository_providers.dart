import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/gym_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/climb_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/project_repository.dart';
import 'database_provider.dart';

final gymRepositoryProvider = Provider<GymRepository>((ref) {
  return GymRepository(ref.watch(databaseProvider));
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(ref.watch(databaseProvider));
});

final climbRepositoryProvider = Provider<ClimbRepository>((ref) {
  return ClimbRepository(ref.watch(databaseProvider));
});

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  return TagRepository(ref.watch(databaseProvider));
});

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(databaseProvider));
});
