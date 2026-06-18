import 'package:drift/drift.dart';
import '../database/database.dart';

class SessionRepository {
  const SessionRepository(this.db);

  final AppDatabase db;

  Future<List<Session>> getAll() => db.sessionsDao.getAll();
  Future<Session?> getById(int id) => db.sessionsDao.getById(id);
  Future<List<Session>> getByGymId(int gymId) => db.sessionsDao.getByGymId(gymId);

  Future<int> start(int gymId, {DateTime? startedAt, int? wallId}) {
    if (gymId <= 0) {
      throw ArgumentError('Invalid gym ID');
    }
    return db.sessionsDao.startSession(
      SessionsCompanion.insert(
        gymId: gymId,
        wallId: Value(wallId),
        startedAt: startedAt ?? DateTime.now(),
      ),
    );
  }

  Future<void> end(int id) => db.sessionsDao.endSession(id, DateTime.now());

  Future<void> delete(int id) => db.sessionsDao.deleteById(id);
}
