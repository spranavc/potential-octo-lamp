import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/services/analytics_service.dart';
import '../../../domain/services/performance_service.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return const AnalyticsService();
});

final performanceServiceProvider = Provider<PerformanceService>((ref) {
  return const PerformanceService();
});

/// Fetches all climbs for analytics computation.
final allClimbsProvider = FutureProvider<List<Climb>>((ref) async {
  final repo = ref.watch(climbRepositoryProvider);
  return repo.getAll();
});

/// Fetches tags for all climbs (climbId to List of Tag).
final climbTagsProvider = FutureProvider<Map<int, List<Tag>>>((ref) async {
  final climbs = await ref.watch(allClimbsProvider.future);
  final repo = ref.watch(climbRepositoryProvider);

  final result = <int, List<Tag>>{};
  for (final climb in climbs) {
    result[climb.id] = await repo.getTagsForClimb(climb.id);
  }
  return result;
});

/// Grade pyramid data: stacked bar chart (sends green, fails red) per V-grade.
final gradeDistributionProvider = FutureProvider<List<GradeDistributionPoint>>((ref) async {
  final climbs = await ref.watch(allClimbsProvider.future);
  final service = ref.watch(analyticsServiceProvider);
  return service.gradeDistribution(climbs);
});

/// Activity heatmap: daily climb counts.
final activityHeatmapProvider = FutureProvider<List<HeatmapDay>>((ref) async {
  final climbs = await ref.watch(allClimbsProvider.future);
  final service = ref.watch(analyticsServiceProvider);
  return service.activityHeatmap(climbs);
});

/// Hardest sends progression: max grade sent per week (cumulative).
final hardestSendsProvider = FutureProvider<List<ProgressionPoint>>((ref) async {
  final climbs = await ref.watch(allClimbsProvider.future);
  final service = ref.watch(analyticsServiceProvider);
  return service.hardestSendsOverTime(climbs);
});

/// Send rate by grade: horizontal bar chart, fraction sent per V-grade.
final sendRateProvider = FutureProvider<List<SendRatePoint>>((ref) async {
  final climbs = await ref.watch(allClimbsProvider.future);
  final service = ref.watch(analyticsServiceProvider);
  return service.sendRateByGrade(climbs);
});

/// Style bias heatmap: send rate per tag/climbing style.
final styleBiasProvider = FutureProvider<List<StyleBiasPoint>>((ref) async {
  final climbs = await ref.watch(allClimbsProvider.future);
  final climbTags = await ref.watch(climbTagsProvider.future);
  final service = ref.watch(analyticsServiceProvider);
  return service.styleBiasHeatmap(climbs, climbTags);
});

// ---------------------------------------------------------------------------
// Performance providers (Phase 5)
// ---------------------------------------------------------------------------

/// Peak window: best send rate by 2-hour time-of-day buckets.
final peakWindowProvider = FutureProvider<List<PeakWindowBucket>>((ref) async {
  final climbs = await ref.watch(allClimbsProvider.future);
  final service = ref.watch(performanceServiceProvider);
  return service.peakWindow(climbs);
});

/// Fatigue trend: average RPE by climb order within session, across all sessions.
final fatigueTrendProvider = FutureProvider<List<FatiguePoint>>((ref) async {
  final climbs = await ref.watch(allClimbsProvider.future);
  // Sort climbs by session then loggedAt for intra-session ordering
  final sorted = List<Climb>.from(climbs)
    ..sort((a, b) {
      final sessionCompare = a.sessionId.compareTo(b.sessionId);
      if (sessionCompare != 0) return sessionCompare;
      return a.loggedAt.compareTo(b.loggedAt);
    });
  final service = ref.watch(performanceServiceProvider);
  return service.fatigueTrendGrouped(sorted);
});

/// Weakness prescription: styles where send rate is >25% below grade-range average.
final weaknessPrescriptionProvider =
    FutureProvider<List<WeaknessPrescription>>((ref) async {
  final climbs = await ref.watch(allClimbsProvider.future);
  final climbTags = await ref.watch(climbTagsProvider.future);
  final service = ref.watch(performanceServiceProvider);
  return service.weaknessPrescription(climbs, climbTags);
});
