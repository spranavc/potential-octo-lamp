import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:climbapp/data/database/database.dart';

import '../test_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('Tags', () {
    test('seed tags are created on database open', () async {
      final tags = await db.tagsDao.getAll();
      final names = tags.map((t) => t.name).toSet();

      expect(names, containsAll(['crimpy', 'dynamic', 'slopey', 'overhang', 'slab']));
      expect(tags.length, 5);
    });
  });

  group('Gyms', () {
    test('CRUD operations', () async {
      // Create
      final id = await db.gymsDao.insertGym('Test Gym');
      expect(id, isPositive);

      // Read
      final gym = await db.gymsDao.getById(id);
      expect(gym, isNotNull);
      expect(gym!.name, 'Test Gym');

      // Update
      await db.gymsDao.updateName(id, 'Updated Gym');
      final updated = await db.gymsDao.getById(id);
      expect(updated!.name, 'Updated Gym');

      // Delete
      await db.gymsDao.deleteById(id);
      final deleted = await db.gymsDao.getById(id);
      expect(deleted, isNull);
    });
  });

  group('Sessions', () {
    late int gymId;

    setUp(() async {
      gymId = await db.gymsDao.insertGym('Session Gym');
    });

    test('start and end a session', () async {
      final startedAt = DateTime(2026, 6, 17, 10, 0, 0);
      final sessionId = await db.sessionsDao.startSession(
        SessionsCompanion.insert(gymId: gymId, startedAt: startedAt),
      );

      final session = await db.sessionsDao.getById(sessionId);
      expect(session, isNotNull);
      expect(session!.startedAt, startedAt);
      expect(session.endedAt, isNull);

      final endedAt = DateTime(2026, 6, 17, 12, 0, 0);
      await db.sessionsDao.endSession(sessionId, endedAt);

      final ended = await db.sessionsDao.getById(sessionId);
      expect(ended!.endedAt, endedAt);
    });

    test('getByGymId returns only sessions for that gym', () async {
      final otherGymId = await db.gymsDao.insertGym('Other Gym');

      await db.sessionsDao.startSession(
        SessionsCompanion.insert(gymId: gymId, startedAt: DateTime.now()),
      );
      await db.sessionsDao.startSession(
        SessionsCompanion.insert(gymId: otherGymId, startedAt: DateTime.now()),
      );

      final gym1Sessions = await db.sessionsDao.getByGymId(gymId);
      final gym2Sessions = await db.sessionsDao.getByGymId(otherGymId);

      expect(gym1Sessions.length, 1);
      expect(gym2Sessions.length, 1);
    });
  });

  group('Climbs', () {
    late int sessionId;

    setUp(() async {
      final gymId = await db.gymsDao.insertGym('Climb Gym');
      sessionId = await db.sessionsDao.startSession(
        SessionsCompanion.insert(gymId: gymId, startedAt: DateTime.now()),
      );
    });

    test('insert and retrieve climbs for a session', () async {
      await db.climbsDao.insertClimb(ClimbsCompanion.insert(
        sessionId: sessionId,
        gradeSystem: 'V-scale',
        gradeValue: 'V5',
        sent: true,
        attempts: Value(2),
        loggedAt: DateTime.now(),
      ));
      await db.climbsDao.insertClimb(ClimbsCompanion.insert(
        sessionId: sessionId,
        gradeSystem: 'V-scale',
        gradeValue: 'V3',
        sent: false,
        attempts: Value(1),
        loggedAt: DateTime.now(),
      ));

      final climbs = await db.climbsDao.getBySessionId(sessionId);
      expect(climbs.length, 2);
      expect(climbs[0].gradeValue, 'V5');
      expect(climbs[0].sent, isTrue);
      expect(climbs[1].gradeValue, 'V3');
      expect(climbs[1].sent, isFalse);
    });

    test('count climbs in session', () async {
      await db.climbsDao.insertClimb(ClimbsCompanion.insert(
        sessionId: sessionId,
        gradeSystem: 'V-scale',
        gradeValue: 'V4',
        sent: true,
        loggedAt: DateTime.now(),
      ));

      final count = await db.climbsDao.countBySession(sessionId);
      expect(count, 1);
    });

    test('delete a climb', () async {
      final id = await db.climbsDao.insertClimb(ClimbsCompanion.insert(
        sessionId: sessionId,
        gradeSystem: 'V-scale',
        gradeValue: 'V2',
        sent: true,
        loggedAt: DateTime.now(),
      ));

      await db.climbsDao.deleteById(id);
      final climb = await db.climbsDao.getById(id);
      expect(climb, isNull);
    });
  });

  group('Projects', () {
    late int gymId;

    setUp(() async {
      gymId = await db.gymsDao.insertGym('Project Gym');
    });

    test('CRUD operations', () async {
      final id = await db.projectsDao.insertProject(
        ProjectsCompanion.insert(
          gymId: gymId,
          name: 'Project V7',
          gradeSystem: 'V-scale',
          gradeValue: 'V7',
        ),
      );

      final project = await db.projectsDao.getById(id);
      expect(project, isNotNull);
      expect(project!.name, 'Project V7');
      expect(project.status, 'active');

      await db.projectsDao.updateStatus(id, 'completed');
      final completed = await db.projectsDao.getById(id);
      expect(completed!.status, 'completed');

      await db.projectsDao.deleteById(id);
      expect(await db.projectsDao.getById(id), isNull);
    });
  });
}
