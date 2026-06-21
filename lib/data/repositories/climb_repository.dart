import 'package:drift/drift.dart';
import '../database/database.dart';

class ClimbRepository {
  const ClimbRepository(this.db);

  final AppDatabase db;

  Future<List<Climb>> getAll({String? userId}) => db.climbsDao.getAll(userId: userId);

  Future<List<Climb>> getBySessionId(int sessionId) =>
      db.climbsDao.getBySessionId(sessionId);

  Future<Climb?> getById(int id) => db.climbsDao.getById(id);

  Future<List<Tag>> getTagsForClimb(int climbId) =>
      db.climbsDao.getTagsForClimb(climbId);

  Future<List<Project>> getProjectsForClimb(int climbId) =>
      db.climbsDao.getProjectsForClimb(climbId);

  Future<int> log({
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
    String? userId,
  }) async {
    if (sessionId <= 0) {
      throw ArgumentError('Invalid session ID');
    }
    if (gradeSystem.trim().isEmpty || gradeValue.trim().isEmpty) {
      throw ArgumentError('Grade system and value are required');
    }
    if (attemptNumber < 1) {
      throw ArgumentError('Attempt number must be at least 1');
    }
    if (rpe != null && (rpe < 1 || rpe > 10)) {
      throw ArgumentError('RPE must be between 1 and 10');
    }

    final climbId = await db.climbsDao.insertClimb(
      ClimbsCompanion.insert(
        sessionId: sessionId,
        gradeSystem: gradeSystem.trim(),
        gradeValue: gradeValue.trim(),
        sent: sent,
        attemptNumber: Value(attemptNumber),
        problemNumber: Value(problemNumber),
        rpe: Value(rpe),
        completionPercent: Value(completionPercent),
        notes: Value(notes?.trim()),
        loggedAt: DateTime.now(),
      ),
      userId: userId,
    );

    // Attach tags if provided
    if (tagIds != null && tagIds.isNotEmpty) {
      await db.batch((b) {
        for (final tagId in tagIds) {
          b.insert(db.climbTags, ClimbTagsCompanion.insert(
            climbId: climbId,
            tagId: tagId,
          ));
        }
      });
    }

    // Attach to projects if provided
    if (projectIds != null && projectIds.isNotEmpty) {
      await db.batch((b) {
        for (final projectId in projectIds) {
          b.insert(db.projectClimbs, ProjectClimbsCompanion.insert(
            projectId: projectId,
            climbId: climbId,
          ));
        }
      });
    }

    return climbId;
  }

  Future<void> delete(int id) => db.climbsDao.deleteById(id);

  Future<int> countBySession(int sessionId) => db.climbsDao.countBySession(sessionId);
}
