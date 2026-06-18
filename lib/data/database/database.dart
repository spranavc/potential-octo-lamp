import 'package:drift/drift.dart';

import 'tables.dart';
import 'connection.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// DAOs
// ---------------------------------------------------------------------------

@DriftAccessor(tables: [Gyms])
class GymsDao extends DatabaseAccessor<AppDatabase> with _$GymsDaoMixin {
  GymsDao(super.attachedDatabase);

  Future<List<Gym>> getAll() => select(gyms).get();

  Future<Gym?> getById(int id) =>
      (select(gyms)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<int> insertGym(String name) =>
      into(gyms).insert(GymsCompanion.insert(name: name));

  Future<void> updateName(int id, String name) =>
      (update(gyms)..where((g) => g.id.equals(id))).write(
        GymsCompanion(name: Value(name)),
      );

  Future<void> deleteById(int id) =>
      (delete(gyms)..where((g) => g.id.equals(id))).go();
}

@DriftAccessor(tables: [Sessions])
class SessionsDao extends DatabaseAccessor<AppDatabase> with _$SessionsDaoMixin {
  SessionsDao(super.attachedDatabase);

  Future<List<Session>> getAll() =>
      (select(sessions)..orderBy([(s) => OrderingTerm.desc(s.startedAt)])).get();

  Future<Session?> getById(int id) =>
      (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<List<Session>> getByGymId(int gymId) =>
      (select(sessions)
            ..where((s) => s.gymId.equals(gymId))
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
          .get();

  Future<int> startSession(SessionsCompanion session) =>
      into(sessions).insert(session);

  Future<void> endSession(int id, DateTime endedAt) =>
      (update(sessions)..where((s) => s.id.equals(id))).write(
        SessionsCompanion(endedAt: Value(endedAt)),
      );

  Future<void> deleteById(int id) =>
      (delete(sessions)..where((s) => s.id.equals(id))).go();
}

@DriftAccessor(tables: [Climbs, ClimbTags, ProjectClimbs, Projects])
class ClimbsDao extends DatabaseAccessor<AppDatabase> with _$ClimbsDaoMixin {
  ClimbsDao(super.attachedDatabase);

  Future<List<Climb>> getBySessionId(int sessionId) =>
      (select(climbs)
            ..where((c) => c.sessionId.equals(sessionId))
            ..orderBy([(c) => OrderingTerm.asc(c.loggedAt)]))
          .get();

  Future<List<Climb>> getAll() =>
      (select(climbs)..orderBy([(c) => OrderingTerm.asc(c.loggedAt)])).get();

  Future<Climb?> getById(int id) =>
      (select(climbs)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// Returns tags attached to [climbId] via the ClimbTags join table.
  Future<List<Tag>> getTagsForClimb(int climbId) {
    final query = select(climbTags).join([
      innerJoin(tags, tags.id.equalsExp(climbTags.tagId)),
    ])
      ..where(climbTags.climbId.equals(climbId));
    return query.map((row) => row.readTable(tags)).get();
  }

  /// Returns projects attached to [climbId] via the ProjectClimbs join table.
  Future<List<Project>> getProjectsForClimb(int climbId) {
    final query = select(projectClimbs).join([
      innerJoin(projects, projects.id.equalsExp(projectClimbs.projectId)),
    ])
      ..where(projectClimbs.climbId.equals(climbId));
    return query.map((row) => row.readTable(projects)).get();
  }

  Future<int> insertClimb(ClimbsCompanion climb) =>
      into(climbs).insert(climb);

  Future<void> deleteById(int id) =>
      (delete(climbs)..where((c) => c.id.equals(id))).go();

  Future<int> countBySession(int sessionId) =>
      (selectOnly(climbs)
            ..addColumns([climbs.id.count()])
            ..where(climbs.sessionId.equals(sessionId)))
          .map((row) => row.read(climbs.id.count()) ?? 0)
          .getSingle();
}

@DriftAccessor(tables: [Tags])
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(super.attachedDatabase);

  Future<List<Tag>> getAll() =>
      (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<Tag?> getByName(String name) =>
      (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<int> insertTag(String name) =>
      into(tags).insert(TagsCompanion.insert(name: name));
}

@DriftAccessor(tables: [Projects])
class ProjectsDao extends DatabaseAccessor<AppDatabase> with _$ProjectsDaoMixin {
  ProjectsDao(super.attachedDatabase);

  Future<List<Project>> getAll() =>
      (select(projects)..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).get();

  Future<Project?> getById(int id) =>
      (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> insertProject(ProjectsCompanion project) =>
      into(projects).insert(project);

  Future<void> updateStatus(int id, String status) =>
      (update(projects)..where((p) => p.id.equals(id))).write(
        ProjectsCompanion(status: Value(status)),
      );

  Future<void> deleteById(int id) =>
      (delete(projects)..where((p) => p.id.equals(id))).go();
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [
    Gyms,
    Walls,
    GymColors,
    Sessions,
    Climbs,
    Tags,
    ClimbTags,
    Projects,
    ProjectClimbs,
  ],
  daos: [
    GymsDao,
    SessionsDao,
    ClimbsDao,
    TagsDao,
    ProjectsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates the production database. Platform is chosen automatically.
  AppDatabase() : super(createConnection());

  /// Creates a database backed by [connection] — useful for in-memory tests.
  AppDatabase.fromConnection(super.connection);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();

          // Seed default tags
          await batch((b) {
            b.insertAll(tags, [
              TagsCompanion.insert(name: 'crimpy'),
              TagsCompanion.insert(name: 'dynamic'),
              TagsCompanion.insert(name: 'slopey'),
              TagsCompanion.insert(name: 'overhang'),
              TagsCompanion.insert(name: 'slab'),
            ]);
          });
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(climbs, climbs.attemptNumber);
            await m.addColumn(climbs, climbs.problemNumber);
          }
          if (from < 3) {
            await m.addColumn(climbs, climbs.completionPercent);
          }
        },
      );
}