import 'package:flutter_test/flutter_test.dart';

import 'package:climbapp/data/database/database.dart';
import 'package:climbapp/data/repositories/session_repository.dart';

import '../test_helpers.dart';

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late int gymId;

  setUp(() async {
    db = await createTestDatabase();
    repo = SessionRepository(db);
    gymId = await db.gymsDao.insertGym('Test Gym');
  });

  tearDown(() async {
    await db.close();
  });

  group('start', () {
    test('creates a session with startedAt timestamp', () async {
      final id = await repo.start(gymId);
      final session = await repo.getById(id);

      expect(session, isNotNull);
      expect(session!.gymId, gymId);
      expect(session.startedAt, isNotNull);
      expect(session.endedAt, isNull);
    });

    test('throws ArgumentError for invalid gymId', () async {
      expect(() => repo.start(0), throwsArgumentError);
      expect(() => repo.start(-1), throwsArgumentError);
    });

    test('accepts optional wallId', () async {
      // Wall is not created yet, but we can pass null
      final id = await repo.start(gymId, wallId: null);
      expect(id, isPositive);
    });
  });

  group('end', () {
    test('sets endedAt timestamp', () async {
      final id = await repo.start(gymId);
      await repo.end(id);

      final session = await repo.getById(id);
      expect(session!.endedAt, isNotNull);
    });
  });

  group('getByGymId', () {
    test('returns sessions for a specific gym', () async {
      await repo.start(gymId);
      await repo.start(gymId);

      final sessions = await repo.getByGymId(gymId);
      expect(sessions.length, 2);
    });
  });

  group('delete', () {
    test('removes the session', () async {
      final id = await repo.start(gymId);
      await repo.delete(id);

      expect(await repo.getById(id), isNull);
    });
  });
}
