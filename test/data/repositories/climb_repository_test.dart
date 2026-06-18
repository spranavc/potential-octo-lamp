import 'package:flutter_test/flutter_test.dart';

import 'package:climbapp/data/database/database.dart';
import 'package:climbapp/data/repositories/climb_repository.dart';

import '../test_helpers.dart';

void main() {
  late AppDatabase db;
  late ClimbRepository repo;
  late int sessionId;

  setUp(() async {
    db = await createTestDatabase();
    repo = ClimbRepository(db);

    final gymId = await db.gymsDao.insertGym('Climb Test Gym');
    sessionId = await db.sessionsDao.startSession(
      SessionsCompanion.insert(gymId: gymId, startedAt: DateTime.now()),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('log', () {
    test('logs a send climb with minimum fields', () async {
      final id = await repo.log(
        sessionId: sessionId,
        gradeSystem: 'V-scale',
        gradeValue: 'V5',
        sent: true,
      );

      final climb = await repo.getById(id);
      expect(climb, isNotNull);
      expect(climb!.gradeSystem, 'V-scale');
      expect(climb.gradeValue, 'V5');
      expect(climb.sent, isTrue);
      expect(climb.attempts, 1); // default
    });

    test('logs a fail climb with attempts and RPE', () async {
      final id = await repo.log(
        sessionId: sessionId,
        gradeSystem: 'Font',
        gradeValue: '6B+',
        sent: false,
        attempts: 5,
        rpe: 8.0,
      );

      final climb = await repo.getById(id);
      expect(climb!.sent, isFalse);
      expect(climb.attempts, 5);
      expect(climb.rpe, 8.0);
    });

    test('logs a climb with tags', () async {
      final tagIds = <int>[];
      for (final name in ['crimpy', 'overhang']) {
        final tag = await db.tagsDao.getByName(name);
        tagIds.add(tag!.id);
      }

      final climbId = await repo.log(
        sessionId: sessionId,
        gradeSystem: 'V-scale',
        gradeValue: 'V4',
        sent: true,
        tagIds: tagIds,
      );

      // Verify tags were attached via climb_tags join table
      final query = db.select(db.climbTags)
        ..where((ct) => ct.climbId.equals(climbId));
      final links = await query.get();
      expect(links.length, 2);
    });

    test('throws ArgumentError for invalid inputs', () async {
      expect(
        () => repo.log(sessionId: 0, gradeSystem: 'V', gradeValue: 'V5', sent: true),
        throwsArgumentError,
      );
      expect(
        () => repo.log(sessionId: sessionId, gradeSystem: '', gradeValue: 'V5', sent: true),
        throwsArgumentError,
      );
      expect(
        () => repo.log(sessionId: sessionId, gradeSystem: 'V', gradeValue: '', sent: true),
        throwsArgumentError,
      );
      expect(
        () => repo.log(sessionId: sessionId, gradeSystem: 'V', gradeValue: 'V5', sent: true, attempts: 0),
        throwsArgumentError,
      );
      expect(
        () => repo.log(sessionId: sessionId, gradeSystem: 'V', gradeValue: 'V5', sent: true, rpe: 11),
        throwsArgumentError,
      );
      expect(
        () => repo.log(sessionId: sessionId, gradeSystem: 'V', gradeValue: 'V5', sent: true, rpe: 0),
        throwsArgumentError,
      );
    });
  });

  group('getBySessionId', () {
    test('returns climbs ordered by loggedAt', () async {
      await repo.log(sessionId: sessionId, gradeSystem: 'V', gradeValue: 'V2', sent: true);
      await repo.log(sessionId: sessionId, gradeSystem: 'V', gradeValue: 'V6', sent: false);

      final climbs = await repo.getBySessionId(sessionId);
      expect(climbs.length, 2);
      expect(climbs[0].gradeValue, 'V2'); // oldest first
    });
  });

  group('countBySession', () {
    test('returns correct count', () async {
      await repo.log(sessionId: sessionId, gradeSystem: 'V', gradeValue: 'V1', sent: true);
      await repo.log(sessionId: sessionId, gradeSystem: 'V', gradeValue: 'V3', sent: true);

      expect(await repo.countBySession(sessionId), 2);
    });
  });

  group('delete', () {
    test('removes the climb', () async {
      final id = await repo.log(
        sessionId: sessionId, gradeSystem: 'V', gradeValue: 'V0', sent: true,
      );
      await repo.delete(id);
      expect(await repo.getById(id), isNull);
    });
  });
}
