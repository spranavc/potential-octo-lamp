import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../../data/providers/database_provider.dart';
import '../../../data/providers/repository_providers.dart';

/// All projects, ordered by creation date (descending).
final projectListProvider = FutureProvider<List<Project>>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getAll();
});

/// A single project by id.
final projectDetailProvider =
    FutureProvider.family<Project?, int>((ref, projectId) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getById(projectId);
});

/// Climbs attached to a project, via the ProjectClimbs join table.
final projectClimbsProvider =
    FutureProvider.family<List<Climb>, int>((ref, projectId) async {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.projectClimbs).join([
    innerJoin(db.climbs, db.climbs.id.equalsExp(db.projectClimbs.climbId)),
  ])
    ..where(db.projectClimbs.projectId.equals(projectId));
  final rows = await query.get();
  return rows.map((row) => row.readTable(db.climbs)).toList();
});

/// Progress data for a project: total climbs, sent count, send rate (0.0-1.0).
final projectProgressProvider =
    FutureProvider.family<({int totalClimbs, int sentClimbs, double sendRate}), int>(
        (ref, projectId) async {
  final climbs = await ref.watch(projectClimbsProvider(projectId).future);
  final totalClimbs = climbs.length;
  final sentClimbs = climbs.where((c) => c.sent).length;
  final sendRate = totalClimbs > 0 ? sentClimbs / totalClimbs : 0.0;
  return (totalClimbs: totalClimbs, sentClimbs: sentClimbs, sendRate: sendRate);
});
