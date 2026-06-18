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

  /// Delete a session and its climbs (cascaded).
  Future<void> deleteSession(int sessionId) {
    return sessionRepo.delete(sessionId);
  }

  /// Log a single climb attempt within a session.
  Future<int> logClimb({
    required int sessionId,
    required String gradeSystem,
    required String gradeValue,
    required bool sent,
    required int attemptNumber,
    required int problemNumber,
    double? rpe,
    int? completionPercent,
    String? notes,
    List<int>? tagIds,
    List<int>? projectIds,
  }) {
    return climbRepo.log(
      sessionId: sessionId,
      gradeSystem: gradeSystem,
      gradeValue: gradeValue,
      sent: sent,
      attemptNumber: attemptNumber,
      problemNumber: problemNumber,
      rpe: rpe,
      completionPercent: completionPercent,
      notes: notes,
      tagIds: tagIds,
      projectIds: projectIds,
    );
  }

  /// Count climbs in a session.
  Future<int> climbCount(int sessionId) {
    return climbRepo.countBySession(sessionId);
  }
}
