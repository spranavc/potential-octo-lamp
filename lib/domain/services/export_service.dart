import 'dart:convert';

import '../../data/repositories/session_repository.dart';
import '../../data/repositories/climb_repository.dart';

class ExportService {
  const ExportService(this.sessionRepo, this.climbRepo);

  final SessionRepository sessionRepo;
  final ClimbRepository climbRepo;

  /// Exports all sessions with their climbs and tags as a JSON string.
  Future<String> exportJson() async {
    final sessions = await sessionRepo.getAll();

    final data = <Map<String, dynamic>>[];

    for (final session in sessions) {
      final climbs = await climbRepo.getBySessionId(session.id);
      final climbData = <Map<String, dynamic>>[];

      for (final climb in climbs) {
        final climbTags = await climbRepo.getTagsForClimb(climb.id);
        final tagNames = climbTags.map((t) => t.name).toList();

        climbData.add({
          'gradeSystem': climb.gradeSystem,
          'gradeValue': climb.gradeValue,
          'sent': climb.sent,
          'attempts': climb.attempts,
          'rpe': climb.rpe,
          'notes': climb.notes,
          'loggedAt': climb.loggedAt.toIso8601String(),
          'tags': tagNames,
        });
      }

      data.add({
        'id': session.id,
        'gymId': session.gymId,
        'wallId': session.wallId,
        'startedAt': session.startedAt.toIso8601String(),
        'endedAt': session.endedAt?.toIso8601String(),
        'notes': session.notes,
        'climbs': climbData,
      });
    }

    return const JsonEncoder.withIndent('  ').convert(data);
  }
}
