import 'package:drift/drift.dart';

import '../database/database.dart';

class GymRepository {
  const GymRepository(this.db);

  final AppDatabase db;

  // ── Gyms ──────────────────────────────────────────────────────────────────

  Future<List<Gym>> getAll() => db.gymsDao.getAll();
  Future<Gym?> getById(int id) => db.gymsDao.getById(id);

  Future<int> create(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Gym name cannot be empty');
    }
    return db.gymsDao.insertGym(name.trim());
  }

  Future<void> updateName(int id, String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Gym name cannot be empty');
    }
    return db.gymsDao.updateName(id, name.trim());
  }

  Future<void> delete(int id) => db.gymsDao.deleteById(id);

  // ── Walls ─────────────────────────────────────────────────────────────────

  Future<List<Wall>> getWalls(int gymId) =>
      (db.select(db.walls)
            ..where((w) => w.gymId.equals(gymId))
            ..orderBy([(w) => OrderingTerm.asc(w.name)]))
          .get();

  Future<int> addWall(int gymId, String name) {
    if (name.trim().isEmpty) throw ArgumentError('Wall name cannot be empty');
    return db.into(db.walls).insert(
          WallsCompanion.insert(gymId: gymId, name: name.trim()),
        );
  }

  Future<void> renameWall(int wallId, String name) {
    if (name.trim().isEmpty) throw ArgumentError('Wall name cannot be empty');
    return (db.update(db.walls)..where((w) => w.id.equals(wallId)))
        .write(WallsCompanion(name: Value(name.trim())));
  }

  Future<void> deleteWall(int wallId) =>
      (db.delete(db.walls)..where((w) => w.id.equals(wallId))).go();

}
