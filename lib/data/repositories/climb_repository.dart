import 'package:drift/drift.dart';
import '../database/database.dart';

class ClimbRepository {
  const ClimbRepository(this.db);

  final AppDatabase db;

  Future<List<Climb>> getBySessionId(int sessionId) =>
      db.climbsDao.getBySessionId(sessionId);

  Future<Climb?> getById(int id) => db.climbsDao.getById(id);

  Future<int> log({
    required int sessionId,
    required String gradeSystem,
    required String gradeValue,
    required bool sent,
    int attempts = 1,
    double? rpe,
    String? notes,
    List<int>? tagIds,
  }) async {
    if (sessionId <= 0) {
      throw ArgumentError('Invalid session ID');
    }
    if (gradeSystem.trim().isEmpty || gradeValue.trim().isEmpty) {
      throw ArgumentError('Grade system and value are required');
    }
    if (attempts < 1) {
      throw ArgumentError('Attempts must be at least 1');
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
        attempts: Value(attempts),
        rpe: Value(rpe),
        notes: Value(notes?.trim()),
        loggedAt: DateTime.now(),
      ),
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

    return climbId;
  }

  Future<void> delete(int id) => db.climbsDao.deleteById(id);

  Future<int> countBySession(int sessionId) => db.climbsDao.countBySession(sessionId);
}
