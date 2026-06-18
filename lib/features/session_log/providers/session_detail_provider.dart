import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';

/// A climb with its tags and linked projects resolved for display.
class ClimbWithTags {
  const ClimbWithTags({
    required this.climb,
    required this.tags,
    required this.projects,
  });

  final Climb climb;
  final List<Tag> tags;
  final List<Project> projects;
}

/// Loads all climbs for a session with their tags and project links attached.
final sessionClimbsProvider =
    FutureProvider.family<List<ClimbWithTags>, int>((ref, sessionId) async {
  final climbRepo = ref.watch(climbRepositoryProvider);
  final climbs = await climbRepo.getBySessionId(sessionId);

  final result = <ClimbWithTags>[];
  for (final climb in climbs) {
    final tags = await climbRepo.getTagsForClimb(climb.id);
    final projects = await climbRepo.getProjectsForClimb(climb.id);
    result.add(ClimbWithTags(climb: climb, tags: tags, projects: projects));
  }
  return result;
});
