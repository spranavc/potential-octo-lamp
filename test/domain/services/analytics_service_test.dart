import 'package:flutter_test/flutter_test.dart';

import 'package:climbapp/data/database/database.dart';
import 'package:climbapp/domain/services/analytics_service.dart';

Climb _makeClimb({
  int id = 1,
  int sessionId = 1,
  required String gradeSystem,
  required String gradeValue,
  required bool sent,
  int attempts = 1,
  DateTime? loggedAt,
}) {
  return Climb(
    id: id,
    sessionId: sessionId,
    gradeSystem: gradeSystem,
    gradeValue: gradeValue,
    sent: sent,
    attempts: attempts,
    rpe: null,
    notes: null,
    loggedAt: loggedAt ?? DateTime(2025, 1, 1),
    createdAt: DateTime.now(),
  );
}

Tag _makeTag({int id = 1, required String name}) {
  return Tag(id: id, name: name, createdAt: DateTime.now());
}

void main() {
  const service = AnalyticsService();

  group('gradeToNum', () {
    test('converts V-scale grades to numeric', () {
      expect(AnalyticsService.vGradeToNum('V0'), 0);
      expect(AnalyticsService.vGradeToNum('V5'), 5);
      expect(AnalyticsService.vGradeToNum('V17'), 17);
    });

    test('returns null for invalid V-scale grades', () {
      expect(AnalyticsService.vGradeToNum('5'), isNull);
      expect(AnalyticsService.vGradeToNum('v5'), isNull);
      expect(AnalyticsService.vGradeToNum('VB'), isNull);
    });

    test('converts Font grades to numeric', () {
      expect(AnalyticsService.fontGradeToNum('6A'), 4);
      expect(AnalyticsService.fontGradeToNum('7A'), 8);
      expect(AnalyticsService.fontGradeToNum('8A'), 13);
    });

    test('returns null for unknown Font grades', () {
      expect(AnalyticsService.fontGradeToNum('9A'), isNull);
      expect(AnalyticsService.fontGradeToNum('XYZ'), isNull);
    });

    test('gradeToNum dispatches by system', () {
      expect(AnalyticsService.gradeToNum('V-scale', 'V3'), 3);
      expect(AnalyticsService.gradeToNum('Font', '7A'), 8);
      expect(AnalyticsService.gradeToNum('Unknown', 'V3'), isNull);
    });
  });

  group('gradeDistribution', () {
    test('returns empty for empty list', () {
      expect(service.gradeDistribution([]).length, 3); // V0-V2 always
    });

    test('counts sends and fails per grade', () {
      final climbs = [
        _makeClimb(id: 1, gradeSystem: 'V-scale', gradeValue: 'V3', sent: true),
        _makeClimb(id: 2, gradeSystem: 'V-scale', gradeValue: 'V3', sent: true),
        _makeClimb(id: 3, gradeSystem: 'V-scale', gradeValue: 'V3', sent: false),
        _makeClimb(id: 4, gradeSystem: 'V-scale', gradeValue: 'V5', sent: true),
      ];

      final result = service.gradeDistribution(climbs);
      expect(result[3].gradeLabel, 'V3');
      expect(result[3].sends, 2);
      expect(result[3].fails, 1);
      expect(result[5].gradeLabel, 'V5');
      expect(result[5].sends, 1);
      expect(result[5].fails, 0);
    });

    test('ignores Font grades', () {
      final climbs = [
        _makeClimb(id: 1, gradeSystem: 'Font', gradeValue: '7A', sent: true),
      ];

      final result = service.gradeDistribution(climbs);
      for (final point in result) {
        expect(point.sends + point.fails, 0);
      }
    });

    test('extends range to max grade', () {
      final climbs = [
        _makeClimb(id: 1, gradeSystem: 'V-scale', gradeValue: 'V10', sent: true),
      ];

      final result = service.gradeDistribution(climbs);
      expect(result.length, 11); // V0 through V10
      expect(result[10].sends, 1);
    });
  });

  group('activityHeatmap', () {
    test('returns empty for empty list', () {
      expect(service.activityHeatmap([]), isEmpty);
    });

    test('groups climbs by day', () {
      final climbs = [
        _makeClimb(id: 1, gradeSystem: 'V-scale', gradeValue: 'V3', sent: true,
          loggedAt: DateTime(2025, 3, 10)),
        _makeClimb(id: 2, gradeSystem: 'V-scale', gradeValue: 'V4', sent: true,
          loggedAt: DateTime(2025, 3, 10)),
        _makeClimb(id: 3, gradeSystem: 'V-scale', gradeValue: 'V5', sent: false,
          loggedAt: DateTime(2025, 3, 12)),
      ];

      final result = service.activityHeatmap(climbs);
      expect(result.length, 3); // March 10, 11, 12
      expect(result[0].climbCount, 2);
      expect(result[1].climbCount, 0);
      expect(result[2].climbCount, 1);
    });

    test('zero-count days are included', () {
      final climbs = [
        _makeClimb(id: 1, gradeSystem: 'V-scale', gradeValue: 'V1', sent: true,
          loggedAt: DateTime(2025, 1, 1)),
        _makeClimb(id: 2, gradeSystem: 'V-scale', gradeValue: 'V2', sent: true,
          loggedAt: DateTime(2025, 1, 5)),
      ];

      final result = service.activityHeatmap(climbs);
      // Jan 1–5 = 5 days
      expect(result.length, 5);
    });
  });

  group('hardestSendsOverTime', () {
    test('returns empty for no sends', () {
      final climbs = [
        _makeClimb(id: 1, gradeSystem: 'V-scale', gradeValue: 'V5', sent: false),
      ];

      expect(service.hardestSendsOverTime(climbs), isEmpty);
    });

    test('returns weekly hardest sends', () {
      // Monday and Wednesday of the same week
      final climbs = [
        _makeClimb(id: 1, gradeSystem: 'V-scale', gradeValue: 'V3', sent: true,
          loggedAt: DateTime(2025, 3, 3)), // Monday
        _makeClimb(id: 2, gradeSystem: 'V-scale', gradeValue: 'V5', sent: true,
          loggedAt: DateTime(2025, 3, 5)), // Wednesday
      ];

      final result = service.hardestSendsOverTime(climbs);
      expect(result.length, 1); // single week
      expect(result.first.maxGrade, 5); // best in that week
    });

    test('cumulative max across weeks', () {
      final climbs = [
        _makeClimb(id: 1, gradeSystem: 'V-scale', gradeValue: 'V3', sent: true,
          loggedAt: DateTime(2025, 3, 3)), // Week 1
        _makeClimb(id: 2, gradeSystem: 'V-scale', gradeValue: 'V7', sent: true,
          loggedAt: DateTime(2025, 3, 10)), // Week 2
        _makeClimb(id: 3, gradeSystem: 'V-scale', gradeValue: 'V5', sent: true,
          loggedAt: DateTime(2025, 3, 17)), // Week 3, lower than V7
      ];

      final result = service.hardestSendsOverTime(climbs);
      expect(result.length, 2); // V3 then V7 (V5 doesn't advance the max)
      expect(result[0].maxGrade, 3);
      expect(result[1].maxGrade, 7);
    });
  });

  group('sendRateByGrade', () {
    test('returns empty for no V-scale climbs', () {
      final climbs = [
        _makeClimb(id: 1, gradeSystem: 'Font', gradeValue: '7A', sent: true),
      ];

      expect(service.sendRateByGrade(climbs), isEmpty);
    });

    test('computes send rate per grade', () {
      final climbs = [
        _makeClimb(id: 1, gradeSystem: 'V-scale', gradeValue: 'V3', sent: true, attempts: 1),
        _makeClimb(id: 2, gradeSystem: 'V-scale', gradeValue: 'V3', sent: false, attempts: 1),
        _makeClimb(id: 3, gradeSystem: 'V-scale', gradeValue: 'V5', sent: true, attempts: 3),
      ];

      final result = service.sendRateByGrade(climbs);
      final v3 = result.firstWhere((p) => p.gradeLabel == 'V3');
      expect(v3.sendRate, 0.5);
      expect(v3.totalAttempts, 2);

      final v5 = result.firstWhere((p) => p.gradeLabel == 'V5');
      expect(v5.sendRate, 1.0 / 3.0);
      expect(v5.totalAttempts, 3);
    });

    test('respects minAttempts filter', () {
      final climbs = [
        _makeClimb(id: 1, gradeSystem: 'V-scale', gradeValue: 'V0', sent: true, attempts: 1),
        _makeClimb(id: 2, gradeSystem: 'V-scale', gradeValue: 'V5', sent: true, attempts: 5),
      ];

      final result = service.sendRateByGrade(climbs, minAttempts: 3);
      expect(result.length, 1);
      expect(result.first.gradeLabel, 'V5');
    });
  });

  group('styleBiasHeatmap', () {
    test('returns empty for no tagged climbs', () {
      expect(service.styleBiasHeatmap([], {}), isEmpty);
    });

    test('computes send rate per tag', () {
      final climbs = [
        _makeClimb(id: 1, gradeSystem: 'V-scale', gradeValue: 'V3', sent: true),
        _makeClimb(id: 2, gradeSystem: 'V-scale', gradeValue: 'V3', sent: false),
        _makeClimb(id: 3, gradeSystem: 'V-scale', gradeValue: 'V5', sent: true),
      ];

      final tags = {
        1: [_makeTag(id: 1, name: 'crimpy')],
        2: [_makeTag(id: 1, name: 'crimpy')],
        3: [_makeTag(id: 2, name: 'dynamic')],
      };

      final result = service.styleBiasHeatmap(climbs, tags);

      // crimpy: 1 send / 2 climbs = 0.5
      final crimpy = result.firstWhere((p) => p.tagName == 'crimpy');
      expect(crimpy.sendRate, 0.5);
      expect(crimpy.totalClimbs, 2);

      // dynamic: 1 send / 1 climb = 1.0
      final dynamicPoint = result.firstWhere((p) => p.tagName == 'dynamic');
      expect(dynamicPoint.sendRate, 1.0);
      expect(dynamicPoint.totalClimbs, 1);
    });

    test('sorted weakest first', () {
      final climbs = [
        _makeClimb(id: 1, gradeSystem: 'V-scale', gradeValue: 'V3', sent: false),
        _makeClimb(id: 2, gradeSystem: 'V-scale', gradeValue: 'V3', sent: true),
        _makeClimb(id: 3, gradeSystem: 'V-scale', gradeValue: 'V5', sent: true),
        _makeClimb(id: 4, gradeSystem: 'V-scale', gradeValue: 'V5', sent: true),
      ];

      final tags = {
        1: [_makeTag(id: 1, name: 'overhang')],
        2: [_makeTag(id: 1, name: 'overhang')],
        3: [_makeTag(id: 2, name: 'slab')],
        4: [_makeTag(id: 2, name: 'slab')],
      };

      final result = service.styleBiasHeatmap(climbs, tags);
      expect(result.first.tagName, 'overhang'); // 0.5 send rate
      expect(result.last.tagName, 'slab'); // 1.0 send rate
    });
  });
}
