import '../../data/repositories/session_repository.dart';
import '../../data/repositories/climb_repository.dart';

/// Business logic for sessions — start, end, log climbs, compute summaries.
class SessionService {
  const SessionService(this.sessionRepo, this.climbRepo);

  final SessionRepository sessionRepo;
  final ClimbRepository climbRepo;

  /// Start a new climbing session.
  Future<int> startSession(int gymId, {int? wallId}) {
    return sessionRepo.start(gymId, wallId: wallId);
  }

  /// End an active session.
  Future<void> endSession(int sessionId) {
    return sessionRepo.end(sessionId);
  }

  /// Log a single climb attempt within a session.
  Future<int> logClimb({
    required int sessionId,
    required String gradeSystem,
    required String gradeValue,
    required bool sent,
    int attempts = 1,
    double? rpe,
    String? notes,
    List<int>? tagIds,
  }) {
    return climbRepo.log(
      sessionId: sessionId,
      gradeSystem: gradeSystem,
      gradeValue: gradeValue,
      sent: sent,
      attempts: attempts,
      rpe: rpe,
      notes: notes,
      tagIds: tagIds,
    );
  }

  /// Count climbs in a session.
  Future<int> climbCount(int sessionId) {
    return climbRepo.countBySession(sessionId);
  }
}
