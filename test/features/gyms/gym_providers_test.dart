import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bolder/data/database/database.dart';
import 'package:bolder/data/providers/database_provider.dart';
import 'package:bolder/data/providers/repository_providers.dart';
import 'package:bolder/features/gyms/providers/gym_providers.dart';

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

  group('gymListProvider', () {
    test('emits empty list when no gyms exist', () async {
      final container = createContainer();
      final gyms = await container.read(gymListProvider.future);
      expect(gyms, isEmpty);
    });

    test('emits all gyms after creation', () async {
      final container = createContainer();

      final repo = container.read(gymRepositoryProvider);
      await repo.create('Test Gym 1');
      await repo.create('Test Gym 2');

      final gyms = await container.read(gymListProvider.future);
      expect(gyms.length, 2);
      expect(gyms.map((g) => g.name), containsAll(['Test Gym 1', 'Test Gym 2']));
    });

    test('reflects deletions', () async {
      final container = createContainer();

      final repo = container.read(gymRepositoryProvider);
      final id = await repo.create('To Delete');
      await repo.delete(id);

      final gyms = await container.read(gymListProvider.future);
      expect(gyms.map((g) => g.id), isNot(contains(id)));
    });
  });

  group('gymDetailProvider', () {
    test('returns gym by id', () async {
      final container = createContainer();

      final repo = container.read(gymRepositoryProvider);
      final id = await repo.create('Detail Gym');

      final gym = await container.read(gymDetailProvider(id).future);
      expect(gym, isNotNull);
      expect(gym!.name, 'Detail Gym');
    });

    test('returns null for unknown id', () async {
      final container = createContainer();

      final gym = await container.read(gymDetailProvider(999).future);
      expect(gym, isNull);
    });
  });

  group('gymWallsProvider', () {
    test('emits walls for a gym', () async {
      final container = createContainer();

      final repo = container.read(gymRepositoryProvider);
      final gymId = await repo.create('Wall Gym');
      await repo.addWall(gymId, 'Main Cave');
      await repo.addWall(gymId, 'Slab Wall');

      final walls = await container.read(gymWallsProvider(gymId).future);
      expect(walls.length, 2);
      expect(walls.map((w) => w.name), containsAll(['Main Cave', 'Slab Wall']));
    });
  });

  group('gymSessionsProvider', () {
    test('emits sessions for a gym', () async {
      final container = createContainer();

      final repo = container.read(gymRepositoryProvider);
      final gymId = await repo.create('Session Gym');

      final sessionRepo = container.read(sessionRepositoryProvider);
      final s1 = await sessionRepo.start(gymId);
      await sessionRepo.start(gymId);
      await sessionRepo.end(s1);

      final sessions = await container.read(gymSessionsProvider(gymId).future);
      expect(sessions.length, 2);
    });
  });
}
