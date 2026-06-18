import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:climbapp/data/database/database.dart';
import 'package:climbapp/data/providers/database_provider.dart';
import 'package:climbapp/data/providers/repository_providers.dart';
import 'package:climbapp/features/projects/providers/project_providers.dart';

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

  /// Helper: create a gym and session, return gymId and sessionId.
  Future<({int gymId, int sessionId})> createGymAndSession(
      ProviderContainer container) async {
    final gymRepo = container.read(gymRepositoryProvider);
    final gymId = await gymRepo.create('Test Gym');

    final sessionRepo = container.read(sessionRepositoryProvider);
    final sessionId = await sessionRepo.start(gymId);

    return (gymId: gymId, sessionId: sessionId);
  }

  group('projectListProvider', () {
    test('emits empty list when no projects exist', () async {
      final container = createContainer();
      final projects = await container.read(projectListProvider.future);
      expect(projects, isEmpty);
    });

    test('emits all projects after creation', () async {
      final container = createContainer();
      final (:gymId, :sessionId) = await createGymAndSession(container);

      final repo = container.read(projectRepositoryProvider);
      await repo.create(
        gymId: gymId,
        name: 'Project Alpha',
        gradeSystem: 'V-scale',
        gradeValue: 'V5',
      );
      await repo.create(
        gymId: gymId,
        name: 'Project Beta',
        gradeSystem: 'Font',
        gradeValue: '7A',
      );

      final projects = await container.read(projectListProvider.future);
      expect(projects.length, 2);
      expect(projects.map((p) => p.name), containsAll(['Project Alpha', 'Project Beta']));
    });
  });

  group('projectDetailProvider', () {
    test('returns project by id', () async {
      final container = createContainer();
      final (:gymId, :sessionId) = await createGymAndSession(container);

      final repo = container.read(projectRepositoryProvider);
      final id = await repo.create(
        gymId: gymId,
        name: 'Detail Project',
        gradeSystem: 'V-scale',
        gradeValue: 'V3',
      );

      final project = await container.read(projectDetailProvider(id).future);
      expect(project, isNotNull);
      expect(project!.name, 'Detail Project');
    });

    test('returns null for unknown id', () async {
      final container = createContainer();

      final project = await container.read(projectDetailProvider(999).future);
      expect(project, isNull);
    });
  });

  group('projectClimbsProvider', () {
    test('returns climbs attached to a project', () async {
      final container = createContainer();
      final (:gymId, :sessionId) = await createGymAndSession(container);

      // Create a project
      final projectRepo = container.read(projectRepositoryProvider);
      final projectId = await projectRepo.create(
        gymId: gymId,
        name: 'Project With Climbs',
        gradeSystem: 'V-scale',
        gradeValue: 'V4',
      );

      // Log some climbs
      final climbRepo = container.read(climbRepositoryProvider);
      final climb1Id = await climbRepo.log(
        sessionId: sessionId,
        gradeSystem: 'V-scale',
        gradeValue: 'V4',
        sent: true,
      );
      final climb2Id = await climbRepo.log(
        sessionId: sessionId,
        gradeSystem: 'V-scale',
        gradeValue: 'V4',
        sent: false,
      );

      // Attach climbs to project via the join table
      await db.into(db.projectClimbs).insert(
            ProjectClimbsCompanion.insert(
              projectId: projectId,
              climbId: climb1Id,
            ),
          );
      await db.into(db.projectClimbs).insert(
            ProjectClimbsCompanion.insert(
              projectId: projectId,
              climbId: climb2Id,
            ),
          );

      final climbs = await container.read(projectClimbsProvider(projectId).future);
      expect(climbs.length, 2);
      expect(climbs.map((c) => c.id), containsAll([climb1Id, climb2Id]));
    });

    test('returns empty list when no climbs attached', () async {
      final container = createContainer();
      final (:gymId, :sessionId) = await createGymAndSession(container);

      final repo = container.read(projectRepositoryProvider);
      final projectId = await repo.create(
        gymId: gymId,
        name: 'Empty Project',
        gradeSystem: 'V-scale',
        gradeValue: 'V2',
      );

      final climbs = await container.read(projectClimbsProvider(projectId).future);
      expect(climbs, isEmpty);
    });
  });

  group('projectProgressProvider', () {
    test('computes correct send rate', () async {
      final container = createContainer();
      final (:gymId, :sessionId) = await createGymAndSession(container);

      final projectRepo = container.read(projectRepositoryProvider);
      final projectId = await projectRepo.create(
        gymId: gymId,
        name: 'Progress Project',
        gradeSystem: 'V-scale',
        gradeValue: 'V5',
      );

      final climbRepo = container.read(climbRepositoryProvider);
      // 3 sends, 2 fails = 3/5 = 60%
      for (var i = 0; i < 3; i++) {
        final climbId = await climbRepo.log(
          sessionId: sessionId,
          gradeSystem: 'V-scale',
          gradeValue: 'V5',
          sent: true,
        );
        await db.into(db.projectClimbs).insert(
              ProjectClimbsCompanion.insert(
                projectId: projectId,
                climbId: climbId,
              ),
            );
      }
      for (var i = 0; i < 2; i++) {
        final climbId = await climbRepo.log(
          sessionId: sessionId,
          gradeSystem: 'V-scale',
          gradeValue: 'V5',
          sent: false,
        );
        await db.into(db.projectClimbs).insert(
              ProjectClimbsCompanion.insert(
                projectId: projectId,
                climbId: climbId,
              ),
            );
      }

      final progress = await container.read(projectProgressProvider(projectId).future);
      expect(progress.totalClimbs, 5);
      expect(progress.sentClimbs, 3);
      expect(progress.sendRate, closeTo(0.6, 0.001));
    });

    test('returns zero send rate for project with no climbs', () async {
      final container = createContainer();
      final (:gymId, :sessionId) = await createGymAndSession(container);

      final repo = container.read(projectRepositoryProvider);
      final projectId = await repo.create(
        gymId: gymId,
        name: 'No Climb Project',
        gradeSystem: 'V-scale',
        gradeValue: 'V3',
      );

      final progress = await container.read(projectProgressProvider(projectId).future);
      expect(progress.totalClimbs, 0);
      expect(progress.sentClimbs, 0);
      expect(progress.sendRate, 0.0);
    });
  });
}
