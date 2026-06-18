import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';

/// A climb with its tags resolved for display.
class ClimbWithTags {
  const ClimbWithTags({
    required this.climb,
    required this.tags,
  });

  final Climb climb;
  final List<Tag> tags;
}

/// Loads all climbs for a session with their tags attached.
final sessionClimbsProvider =
    FutureProvider.family<List<ClimbWithTags>, int>((ref, sessionId) async {
  final climbRepo = ref.watch(climbRepositoryProvider);
  final climbs = await climbRepo.getBySessionId(sessionId);

  final result = <ClimbWithTags>[];
  for (final climb in climbs) {
    final tags = await climbRepo.getTagsForClimb(climb.id);
    result.add(ClimbWithTags(climb: climb, tags: tags));
  }
  return result;
});
