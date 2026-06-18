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

  // ── Gym Colors ────────────────────────────────────────────────────────────

  Future<List<GymColor>> getColors(int gymId) =>
      (db.select(db.gymColors)
            ..where((c) => c.gymId.equals(gymId))
            ..orderBy([(c) => OrderingTerm.asc(c.gradeValue)]))
          .get();

  Future<int> addColor({
    required int gymId,
    required String colorName,
    required String colorHex,
    required String gradeSystem,
    required String gradeValue,
  }) {
    if (colorName.trim().isEmpty) throw ArgumentError('Color name cannot be empty');
    if (gradeSystem.trim().isEmpty) throw ArgumentError('Grade system cannot be empty');
    if (gradeValue.trim().isEmpty) throw ArgumentError('Grade value cannot be empty');
    return db.into(db.gymColors).insert(
          GymColorsCompanion.insert(
            gymId: gymId,
            colorName: colorName.trim(),
            colorHex: colorHex,
            gradeSystem: gradeSystem.trim(),
            gradeValue: gradeValue.trim(),
          ),
        );
  }

  Future<void> updateColor(
    int colorId, {
    required String colorName,
    required String colorHex,
    required String gradeSystem,
    required String gradeValue,
  }) {
    if (colorName.trim().isEmpty) throw ArgumentError('Color name cannot be empty');
    return (db.update(db.gymColors)..where((c) => c.id.equals(colorId)))
        .write(GymColorsCompanion(
      colorName: Value(colorName.trim()),
      colorHex: Value(colorHex),
      gradeSystem: Value(gradeSystem.trim()),
      gradeValue: Value(gradeValue.trim()),
    ));
  }

  Future<void> deleteColor(int colorId) =>
      (db.delete(db.gymColors)..where((c) => c.id.equals(colorId))).go();
}
