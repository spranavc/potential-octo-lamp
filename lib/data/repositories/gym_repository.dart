import '../database/database.dart';

class GymRepository {
  const GymRepository(this.db);

  final AppDatabase db;

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
}
