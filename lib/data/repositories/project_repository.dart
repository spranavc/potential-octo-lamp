import 'package:drift/drift.dart';
import '../database/database.dart';

class ProjectRepository {
  const ProjectRepository(this.db);

  final AppDatabase db;

  Future<List<Project>> getAll() => db.projectsDao.getAll();
  Future<Project?> getById(int id) => db.projectsDao.getById(id);

  Future<int> create({
    required int gymId,
    required String name,
    required String gradeSystem,
    required String gradeValue,
    String? description,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Project name cannot be empty');
    }
    if (gradeSystem.trim().isEmpty || gradeValue.trim().isEmpty) {
      throw ArgumentError('Grade system and value are required');
    }
    return db.projectsDao.insertProject(
      ProjectsCompanion.insert(
        gymId: gymId,
        name: name.trim(),
        gradeSystem: gradeSystem.trim(),
        gradeValue: gradeValue.trim(),
        description: Value(description?.trim()),
        startedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markCompleted(int id) =>
      db.projectsDao.updateStatus(id, 'completed');

  Future<void> markAbandoned(int id) =>
      db.projectsDao.updateStatus(id, 'abandoned');

  Future<void> delete(int id) => db.projectsDao.deleteById(id);
}
