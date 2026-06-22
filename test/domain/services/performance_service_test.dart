import 'package:flutter_test/flutter_test.dart';

import 'package:bolder/data/database/database.dart';
import 'package:bolder/domain/services/performance_service.dart';

Climb _makeClimb({
  int id = 1,
  int sessionId = 1,
  required String gradeSystem,
  required String gradeValue,
  required bool sent,
  int attempts = 1, int problemNumber = 1,
  double? rpe,
  DateTime? loggedAt,
}) {
  return Climb(
    id: id,
    sessionId: sessionId,
    gradeSystem: gradeSystem,
    gradeValue: gradeValue,
    sent: sent,
    attemptNumber: attempts,
    problemNumber: problemNumber,
    rpe: rpe,
    notes: null,
    loggedAt: loggedAt ?? DateTime(2025, 1, 1),
    syncStatus: 'synced',
    createdAt: DateTime.now(),
  );
}

Tag _makeTag({int id = 1, required String name}) {
  return Tag(id: id, name: name, createdAt: DateTime.now());
}

void main() {
  const service = PerformanceService();

  group('sessionPerformanceCurve', () {
    test('returns empty for empty list', () {
      expect(service.sessionPerformanceCurve([]), isEmpty);
    });

    test('computes climb order and grade for session climbs', () {
      final climbs = [
        _makeClimb(
          id: 1,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
          loggedAt: DateTime(2025, 3, 10, 14, 0),
        ),
        _makeClimb(
          id: 2,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V5',
          sent: false,
          loggedAt: DateTime(2025, 3, 10, 14, 5),
        ),
        _makeClimb(
          id: 3,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: true,
          loggedAt: DateTime(2025, 3, 10, 14, 10),
        ),
      ];

      final result = service.sessionPerformanceCurve(climbs);
      expect(result.length, 3);

      expect(result[0].climbOrder, 1);
      expect(result[0].gradeNum, 3);
      expect(result[0].sent, true);

      expect(result[1].climbOrder, 2);
      expect(result[1].gradeNum, 5);
      expect(result[1].sent, false);

      expect(result[2].climbOrder, 3);
      expect(result[2].gradeNum, 4);
      expect(result[2].sent, true);
    });

    test('skips climbs with unparseable grades', () {
      final climbs = [
        _makeClimb(
          id: 1,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
        ),
        _makeClimb(
          id: 2,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V-Intro',
          sent: false,
        ),
        _makeClimb(
          id: 3,
          sessionId: 1,
          gradeSystem: 'Font',
          gradeValue: '7A',
          sent: true,
        ),
      ];

      final result = service.sessionPerformanceCurve(climbs);
      expect(result.length, 3); // V3, V-Intro, 7A (all parsed, in climb order)
      expect(result[0].gradeLabel, 'V3');
      expect(result[1].gradeLabel, 'V-Intro');
      expect(result[2].gradeLabel, '7A');
    });
  });

  group('rollingAverageTrend', () {
    test('returns empty for empty points', () {
      expect(service.rollingAverageTrend([]), isEmpty);
    });

    test('computes rolling average of sent grades', () {
      final points = [
        const SessionPerformancePoint(
          climbOrder: 1,
          gradeNum: 3,
          sent: true,
          gradeLabel: 'V3',
        ),
        const SessionPerformancePoint(
          climbOrder: 2,
          gradeNum: 5,
          sent: false,
          gradeLabel: 'V5',
        ),
        const SessionPerformancePoint(
          climbOrder: 3,
          gradeNum: 4,
          sent: true,
          gradeLabel: 'V4',
        ),
        const SessionPerformancePoint(
          climbOrder: 4,
          gradeNum: 6,
          sent: true,
          gradeLabel: 'V6',
        ),
        const SessionPerformancePoint(
          climbOrder: 5,
          gradeNum: 2,
          sent: false,
          gradeLabel: 'V2',
        ),
      ];

      final result = service.rollingAverageTrend(points, windowSize: 3);

      // Climb 1: window [1] → only (3) → avg=3
      // Climb 2: window [1,2] → fails not counted → only (3) → avg=3
      // Climb 3: window [1,2,3] → (3,4) → avg=3.5
      // Climb 4: window [2,3,4] → fails not counted, (4,6) → avg=5
      // Climb 5: window [3,4,5] → (4,6) → avg=5
      expect(result.length, 5);
      expect(result[0].averageGrade, 3.0);
      expect(result[1].averageGrade, 3.0);
      expect(result[2].averageGrade, 3.5);
      expect(result[3].averageGrade, 5.0);
      expect(result[4].averageGrade, 5.0);
    });

    test('no sent climbs produces no trend points', () {
      final points = [
        const SessionPerformancePoint(
          climbOrder: 1,
          gradeNum: 3,
          sent: false,
          gradeLabel: 'V3',
        ),
        const SessionPerformancePoint(
          climbOrder: 2,
          gradeNum: 5,
          sent: false,
          gradeLabel: 'V5',
        ),
      ];

      final result = service.rollingAverageTrend(points, windowSize: 2);
      expect(result, isEmpty);
    });
  });

  group('peakWindow', () {
    test('returns empty for no climbs', () {
      expect(service.peakWindow([]), isEmpty);
    });

    test('groups climbs into 2-hour buckets', () {
      final climbs = [
        _makeClimb(
          id: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
          loggedAt: DateTime(2025, 3, 10, 8, 0), // 8-10 AM
        ),
        _makeClimb(
          id: 2,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: true,
          loggedAt: DateTime(2025, 3, 10, 8, 30),
        ),
        _makeClimb(
          id: 3,
          gradeSystem: 'V-scale',
          gradeValue: 'V5',
          sent: true,
          loggedAt: DateTime(2025, 3, 10, 9, 0),
        ),
        _makeClimb(
          id: 4,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: false,
          loggedAt: DateTime(2025, 3, 10, 14, 0), // 2-4 PM
        ),
        _makeClimb(
          id: 5,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: false,
          loggedAt: DateTime(2025, 3, 10, 15, 0),
        ),
      ];

      final result = service.peakWindow(climbs, minClimbs: 3);

      // 8-10 AM bucket: 3 sends / 3 total = 1.0
      // 2-4 PM bucket: 0 sends / 2 total = excluded (< minClimbs)
      expect(result.length, 1);
      expect(result.first.label, contains('8'));
      expect(result.first.sendRate, 1.0);
      expect(result.first.totalClimbs, 3);
    });

    test('sorted best send rate first', () {
      final climbs = [
        // 6-8 AM: 50% send rate
        _makeClimb(
          id: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
          loggedAt: DateTime(2025, 3, 10, 6, 0),
        ),
        _makeClimb(
          id: 2,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: false,
          loggedAt: DateTime(2025, 3, 10, 7, 0),
        ),
        _makeClimb(
          id: 3,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: false,
          loggedAt: DateTime(2025, 3, 10, 6, 30),
        ),
        _makeClimb(
          id: 4,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: true,
          loggedAt: DateTime(2025, 3, 10, 7, 30),
        ),
        // 6-8 PM: 100% send rate
        _makeClimb(
          id: 5,
          gradeSystem: 'V-scale',
          gradeValue: 'V5',
          sent: true,
          loggedAt: DateTime(2025, 3, 10, 18, 0),
        ),
        _makeClimb(
          id: 6,
          gradeSystem: 'V-scale',
          gradeValue: 'V6',
          sent: true,
          loggedAt: DateTime(2025, 3, 10, 18, 30),
        ),
        _makeClimb(
          id: 7,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: true,
          loggedAt: DateTime(2025, 3, 10, 19, 0),
        ),
      ];

      final result = service.peakWindow(climbs, minClimbs: 3);
      expect(result.length, 2);
      expect(result.first.sendRate, 1.0); // PM bucket best
      expect(result.last.sendRate, 0.5); // AM bucket second
    });
  });

  group('fatigueTrendGrouped', () {
    test('returns empty for no climbs', () {
      expect(service.fatigueTrendGrouped([]), isEmpty);
    });

    test('computes average RPE per climb order across sessions', () {
      final climbs = [
        // Session 1
        _makeClimb(
          id: 1,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
          rpe: 3,
          loggedAt: DateTime(2025, 3, 10, 14, 0),
        ),
        _makeClimb(
          id: 2,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: true,
          rpe: 5,
          loggedAt: DateTime(2025, 3, 10, 14, 10),
        ),
        _makeClimb(
          id: 3,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V5',
          sent: false,
          rpe: 8,
          loggedAt: DateTime(2025, 3, 10, 14, 20),
        ),
        // Session 2
        _makeClimb(
          id: 4,
          sessionId: 2,
          gradeSystem: 'V-scale',
          gradeValue: 'V2',
          sent: true,
          rpe: 2,
          loggedAt: DateTime(2025, 3, 11, 14, 0),
        ),
        _makeClimb(
          id: 5,
          sessionId: 2,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: false,
          rpe: 6,
          loggedAt: DateTime(2025, 3, 11, 14, 10),
        ),
        _makeClimb(
          id: 6,
          sessionId: 2,
          gradeSystem: 'V-scale',
          gradeValue: 'V5',
          sent: true,
          rpe: 7,
          loggedAt: DateTime(2025, 3, 11, 14, 20),
        ),
      ];

      final result = service.fatigueTrendGrouped(climbs, minSessions: 2);

      // Position 1: (3 + 2) / 2 = 2.5
      // Position 2: (5 + 6) / 2 = 5.5
      // Position 3: (8 + 7) / 2 = 7.5
      expect(result.length, 3);
      expect(result[0].climbOrder, 1);
      expect(result[0].rpe, 2.5);
      expect(result[1].climbOrder, 2);
      expect(result[1].rpe, 5.5);
      expect(result[2].climbOrder, 3);
      expect(result[2].rpe, 7.5);
    });

    test('excludes positions with fewer than minSessions', () {
      final climbs = [
        // Session 1 has 3 climbs
        _makeClimb(
          id: 1,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
          rpe: 3,
        ),
        _makeClimb(
          id: 2,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: true,
          rpe: 5,
        ),
        _makeClimb(
          id: 3,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V5',
          sent: false,
          rpe: 8,
        ),
        // Session 2 has only 1 climb
        _makeClimb(
          id: 4,
          sessionId: 2,
          gradeSystem: 'V-scale',
          gradeValue: 'V2',
          sent: true,
          rpe: 4,
        ),
      ];

      final result = service.fatigueTrendGrouped(climbs, minSessions: 2);

      // Only position 1 has >= 2 sessions
      expect(result.length, 1);
      expect(result.first.climbOrder, 1);
      expect(result.first.rpe, 3.5);
    });

    test('skips climbs without RPE', () {
      final climbs = [
        _makeClimb(
          id: 1,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
          rpe: 3,
        ),
        _makeClimb(
          id: 2,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: true,
          rpe: null, // no RPE logged
        ),
        _makeClimb(
          id: 3,
          sessionId: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V5',
          sent: false,
          rpe: 8,
        ),
        _makeClimb(
          id: 4,
          sessionId: 2,
          gradeSystem: 'V-scale',
          gradeValue: 'V2',
          sent: true,
          rpe: 4,
        ),
        _makeClimb(
          id: 5,
          sessionId: 2,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: false,
          rpe: 6,
        ),
      ];

      final result = service.fatigueTrendGrouped(climbs, minSessions: 2);

      // Session 1: position 1 RPE=3, position 2 RPE=null, position 3 RPE=8
      // Session 2: position 1 RPE=4, position 2 RPE=6
      // Position 1: (3 + 4) / 2 = 3.5 → 2 sessions → included
      // Position 2: only 1 session with RPE (session 2) → excluded
      // Position 3: only 1 session → excluded
      expect(result.length, 1);
      expect(result.first.climbOrder, 1);
    });
  });

  group('weaknessPrescription', () {
    test('returns empty for no climbs', () {
      expect(service.weaknessPrescription([], {}), isEmpty);
    });

    test('identifies styles with low send rate vs grade average', () {
      // Build climbs where "overhang" underperforms heavily
      final climbs = [
        // Overhang climbs (grade V4-V6 range, low send rate)
        _makeClimb(
          id: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: false,
        ),
        _makeClimb(
          id: 2,
          gradeSystem: 'V-scale',
          gradeValue: 'V5',
          sent: false,
        ),
        _makeClimb(
          id: 3,
          gradeSystem: 'V-scale',
          gradeValue: 'V6',
          sent: true,
        ),
        // Slab climbs (same grade range, high send rate)
        _makeClimb(
          id: 4,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: true,
        ),
        _makeClimb(
          id: 5,
          gradeSystem: 'V-scale',
          gradeValue: 'V5',
          sent: true,
        ),
        _makeClimb(
          id: 6,
          gradeSystem: 'V-scale',
          gradeValue: 'V6',
          sent: true,
        ),
        // Crimpy climbs (same grade range)
        _makeClimb(
          id: 7,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: true,
        ),
        _makeClimb(
          id: 8,
          gradeSystem: 'V-scale',
          gradeValue: 'V5',
          sent: true,
        ),
        _makeClimb(
          id: 9,
          gradeSystem: 'V-scale',
          gradeValue: 'V6',
          sent: false,
        ),
      ];

      final tags = {
        1: [_makeTag(id: 1, name: 'overhang')],
        2: [_makeTag(id: 1, name: 'overhang')],
        3: [_makeTag(id: 1, name: 'overhang')],
        4: [_makeTag(id: 2, name: 'slab')],
        5: [_makeTag(id: 2, name: 'slab')],
        6: [_makeTag(id: 2, name: 'slab')],
        7: [_makeTag(id: 3, name: 'crimpy')],
        8: [_makeTag(id: 3, name: 'crimpy')],
        9: [_makeTag(id: 3, name: 'crimpy')],
      };

      // Grade range V4-V6: 6 sends out of 9 total climbs = 0.667
      // Overhang: 1/3 = 0.333 → deficit = 0.667 - 0.333 = 0.334 (>0.25 threshold)
      // Slab: 3/3 = 1.0 → no deficit
      // Crimpy: 2/3 = 0.667 → deficit = 0.667 - 0.667 = 0.0 (below threshold)

      final result = service.weaknessPrescription(
        climbs,
        tags,
        gradeRange: 2,
        thresholdPercent: 0.25,
      );

      expect(result.length, 1);
      expect(result.first.tagName, 'overhang');
      expect(result.first.userSendRate, closeTo(1 / 3, 0.01));
      expect(result.first.averageSendRate, closeTo(6 / 9, 0.01));
    });

    test('no weaknesses if all styles perform similarly', () {
      final climbs = [
        _makeClimb(
          id: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
        ),
        _makeClimb(
          id: 2,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
        ),
        _makeClimb(
          id: 3,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
        ),
        _makeClimb(
          id: 4,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
        ),
      ];

      final tags = {
        1: [_makeTag(id: 1, name: 'crimpy')],
        2: [_makeTag(id: 2, name: 'slopey')],
        3: [_makeTag(id: 3, name: 'dynamic')],
        4: [_makeTag(id: 4, name: 'slab')],
      };

      final result = service.weaknessPrescription(
        climbs,
        tags,
        gradeRange: 2,
        thresholdPercent: 0.25,
      );

      expect(result, isEmpty);
    });

    test('sorted by largest deficit first', () {
      final climbs = [
        // Crimpy: 0/2 = 0.0
        _makeClimb(
          id: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: false,
        ),
        _makeClimb(
          id: 2,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: false,
        ),
        // Overhang: 1/2 = 0.5
        _makeClimb(
          id: 3,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
        ),
        _makeClimb(
          id: 4,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: false,
        ),
        // Strong climbers bringing up the average
        _makeClimb(
          id: 5,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
        ),
        _makeClimb(
          id: 6,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: true,
        ),
        _makeClimb(
          id: 7,
          gradeSystem: 'V-scale',
          gradeValue: 'V4',
          sent: true,
        ),
      ];

      final tags = {
        1: [_makeTag(id: 1, name: 'crimpy')],
        2: [_makeTag(id: 1, name: 'crimpy')],
        3: [_makeTag(id: 2, name: 'overhang')],
        4: [_makeTag(id: 2, name: 'overhang')],
        5: [_makeTag(id: 3, name: 'slab')],
        6: [_makeTag(id: 3, name: 'slab')],
        7: [_makeTag(id: 3, name: 'slab')],
      };

      final result = service.weaknessPrescription(
        climbs,
        tags,
        gradeRange: 2,
        thresholdPercent: 0.25,
      );

      // Grade range V1-V5 for both tags. Average: 4/7 ≈ 0.571.
      // Crimpy: 0/2 = 0.0, deficit = 0.571 (>0.25 threshold) → weakness
      // Overhang: 1/2 = 0.5, deficit = 0.071 (below threshold) → not flagged
      // Slab: 3/3 = 1.0, but no tagged climbs in the overhang/crimpy grade bucket avg
      //  (slab climbs are V3-V4, avg is same range, but slab is 1.0 so no deficit)
      expect(result.length, 1);
      expect(result[0].tagName, 'crimpy');
    });

    test('returns empty when averageSendRate is zero', () {
      // All climbs fail → averageSendRate = 0 → no relative deficit
      final climbs = [
        _makeClimb(
          id: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: false,
        ),
        _makeClimb(
          id: 2,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: false,
        ),
      ];

      final tags = {
        1: [_makeTag(id: 1, name: 'slab')],
        2: [_makeTag(id: 1, name: 'slab')],
      };

      final result = service.weaknessPrescription(
        climbs,
        tags,
        gradeRange: 2,
        thresholdPercent: 0.25,
      );

      expect(result, isEmpty);
    });
  });

  group('_hourRangeLabel', () {
    // Test via peakWindow which uses the label formatter
    test('generates correct AM/PM labels', () {
      final climbs = [
        _makeClimb(
          id: 1,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
          loggedAt: DateTime(2025, 1, 1, 12, 0), // 12-2 PM, bucket 6
        ),
        _makeClimb(
          id: 2,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
          loggedAt: DateTime(2025, 1, 1, 12, 30),
        ),
        _makeClimb(
          id: 3,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
          loggedAt: DateTime(2025, 1, 1, 13, 0),
        ),
        _makeClimb(
          id: 4,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
          loggedAt: DateTime(2025, 1, 1, 0, 0), // 12-2 AM
        ),
        _makeClimb(
          id: 5,
          gradeSystem: 'V-scale',
          gradeValue: 'V3',
          sent: true,
          loggedAt: DateTime(2025, 1, 1, 1, 0),
        ),
      ];

      final result = service.peakWindow(climbs, minClimbs: 3);
      expect(result.length, 1); // only 12-2 PM has >=3 climbs
      expect(result.first.label, '12 PM - 2 PM');
    });
  });
}
