import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:climbapp/data/database/database.dart';
import 'package:climbapp/data/providers/database_provider.dart';
import 'package:climbapp/data/providers/repository_providers.dart';
import 'package:climbapp/features/analytics/providers/analytics_providers.dart';

import '../../data/test_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('allClimbsProvider', () {
    test('emits empty list when no climbs exist', () async {
      final container = createContainer();
      final climbs = await container.read(allClimbsProvider.future);
      expect(climbs, isEmpty);
    });

    test('emits all climbs', () async {
      final container = createContainer();

      // Create a gym and session first
      final gymId = await db.gymsDao.insertGym('Test Gym');
      final sessionId = await db.sessionsDao.startSession(
        SessionsCompanion.insert(gymId: gymId, startedAt: DateTime.now()),
      );

      // Add climbs
      final repo = container.read(climbRepositoryProvider);
      await repo.log(
        sessionId: sessionId,
        gradeSystem: 'V-scale',
        gradeValue: 'V3',
        sent: true,
        attemptNumber: 1,
        problemNumber: 1,
      );
      await repo.log(
        sessionId: sessionId,
        gradeSystem: 'V-scale',
        gradeValue: 'V5',
        sent: false,
        attemptNumber: 1,
        problemNumber: 1,
      );

      final climbs = await container.read(allClimbsProvider.future);
      expect(climbs.length, 2);
    });
  });

  group('gradeDistributionProvider', () {
    test('emits data with no sends/fails when no climbs', () async {
      final container = createContainer();
      final data = await container.read(gradeDistributionProvider.future);
      expect(data.isNotEmpty, isTrue);
      for (final point in data) {
        expect(point.sends + point.fails, 0);
      }
    });

    test('computes correct distribution from climbs', () async {
      final container = createContainer();

      final gymId = await db.gymsDao.insertGym('Test Gym');
      final sessionId = await db.sessionsDao.startSession(
        SessionsCompanion.insert(gymId: gymId, startedAt: DateTime.now()),
      );

      final repo = container.read(climbRepositoryProvider);
      await repo.log(sessionId: sessionId, gradeSystem: 'V-scale', gradeValue: 'V2', sent: true, attemptNumber: 1, problemNumber: 1);
      await repo.log(sessionId: sessionId, gradeSystem: 'V-scale', gradeValue: 'V2', sent: false, attemptNumber: 1, problemNumber: 1);
      await repo.log(sessionId: sessionId, gradeSystem: 'V-scale', gradeValue: 'V4', sent: true, attemptNumber: 1, problemNumber: 1);

      final data = await container.read(gradeDistributionProvider.future);
      final v2 = data.firstWhere((p) => p.gradeLabel == 'V2');
      expect(v2.sends, 1);
      expect(v2.fails, 1);
    });
  });

  group('activityHeatmapProvider', () {
    test('emits empty when no climbs', () async {
      final container = createContainer();
      final data = await container.read(activityHeatmapProvider.future);
      expect(data, isEmpty);
    });

    test('emits daily counts', () async {
      final container = createContainer();

      final gymId = await db.gymsDao.insertGym('Test Gym');
      final sessionId = await db.sessionsDao.startSession(
        SessionsCompanion.insert(gymId: gymId, startedAt: DateTime.now()),
      );

      final repo = container.read(climbRepositoryProvider);
      await repo.log(sessionId: sessionId, gradeSystem: 'V-scale', gradeValue: 'V1', sent: true, attemptNumber: 1, problemNumber: 1);

      final data = await container.read(activityHeatmapProvider.future);
      expect(data.length, 1);
      expect(data.first.climbCount, 1);
    });
  });

  group('sendRateProvider', () {
    test('emits empty when no V-scale climbs', () async {
      final container = createContainer();
      final data = await container.read(sendRateProvider.future);
      expect(data, isEmpty);
    });
  });

  group('hardestSendsProvider', () {
    test('emits empty when no sends', () async {
      final container = createContainer();
      final data = await container.read(hardestSendsProvider.future);
      expect(data, isEmpty);
    });
  });
}
