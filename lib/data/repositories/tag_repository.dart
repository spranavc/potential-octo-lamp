import '../database/database.dart';

class TagRepository {
  const TagRepository(this.db);

  final AppDatabase db;

  Future<List<Tag>> getAll() => db.tagsDao.getAll();

  Future<Tag?> getByName(String name) => db.tagsDao.getByName(name);

  Future<int> create(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Tag name cannot be empty');
    }
    return db.tagsDao.insertTag(name.trim().toLowerCase());
  }
}
