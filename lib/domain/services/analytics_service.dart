import '../../data/database/database.dart';

// ---------------------------------------------------------------------------
// Data transfer objects — returned by AnalyticsService methods
// ---------------------------------------------------------------------------

/// Grade pyramid data point: sends and fails at a specific grade.
class GradeDistributionPoint {
  final int gradeNum;
  final String gradeLabel;
  final int sends;
  final int fails;

  const GradeDistributionPoint({
    required this.gradeNum,
    required this.gradeLabel,
    required this.sends,
    required this.fails,
  });
}

/// A single day's activity count for the heatmap.
class HeatmapDay {
  final DateTime date;
  final int climbCount;

  const HeatmapDay({required this.date, required this.climbCount});
}

/// A data point for the progression line chart.
class ProgressionPoint {
  final DateTime date;
  final int maxGrade;

  const ProgressionPoint({required this.date, required this.maxGrade});
}

/// Send rate data for the horizontal bar chart.
class SendRatePoint {
  final String gradeLabel;
  final double sendRate; // 0.0 to 1.0
  final int totalAttempts;

  const SendRatePoint({
    required this.gradeLabel,
    required this.sendRate,
    required this.totalAttempts,
  });
}

/// Style bias data for the anti-style compass.
class StyleBiasPoint {
  final String tagName;
  final double sendRate; // 0.0 to 1.0
  final int totalClimbs;

  const StyleBiasPoint({
    required this.tagName,
    required this.sendRate,
    required this.totalClimbs,
  });
}

// ---------------------------------------------------------------------------
// AnalyticsService
// ---------------------------------------------------------------------------

/// Pure computation service for analytics.
///
/// Takes climb data and returns computed analytics results. No direct database
/// access — widgets receive pre-computed data from providers that call these
/// methods.
class AnalyticsService {
  const AnalyticsService();

  // ---------------------------------------------------------------------------
  // Grade helpers
  // ---------------------------------------------------------------------------

  /// Converts a V-scale grade string (e.g. "V5") to a numeric value.
  /// Returns null for unrecognized formats.
  static int? vGradeToNum(String gradeValue) {
    if (gradeValue.startsWith('V')) {
      return int.tryParse(gradeValue.substring(1));
    }
    return null;
  }

  /// Converts a Font grade string (e.g. "6B+", "7A") to a numeric value
  /// for charting. Font grades are mapped to their approximate V-scale
  /// equivalent by using the numeric portion times a base offset.
  static int? fontGradeToNum(String gradeValue) {
    // Map of Font grade to approximate V-scale equivalent for sorting
    const fontToV = <String, int>{
      '1': 0, '2': 0, '3': 0, // VB
      '4': 1,                 // V0
      '5': 3,                 // V1-V2
      '5+': 3,                // V2
      '6A': 4, '6A+': 5,     // V3-V4
      '6B': 5, '6B+': 6,     // V4-V5
      '6C': 7, '6C+': 8,     // V5-V6
      '7A': 8, '7A+': 9,     // V7-V8
      '7B': 10, '7B+': 11,   // V9-V10
      '7C': 12, '7C+': 13,   // V10-V11
      '8A': 13, '8A+': 14,   // V12-V13
      '8B': 15, '8B+': 16,   // V14-V15
      '8C': 17, '8C+': 18,   // V16-V17
    };
    return fontToV[gradeValue];
  }

  /// Converts any grade to a numeric value for charting (0-17 scale).
  /// Returns null if the grade cannot be parsed.
  static int? gradeToNum(String gradeSystem, String gradeValue) {
    if (gradeSystem == 'V-scale') {
      return vGradeToNum(gradeValue);
    } else if (gradeSystem == 'Font') {
      return fontGradeToNum(gradeValue);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Grade Pyramid
  // ---------------------------------------------------------------------------

  /// Returns grade distribution data for the grade pyramid chart.
  ///
  /// Groups climbs by grade (V0-V17) and counts sends vs fails.
  /// Only V-scale grades are included (Font grades are excluded from the
  /// pyramid since they use a different scale — callers can filter or
  /// convert before passing data).
  List<GradeDistributionPoint> gradeDistribution(List<Climb> climbs) {
    final vClimbs = climbs.where(
      (c) => c.gradeSystem == 'V-scale',
    );

    final Map<int, int> sends = {};
    final Map<int, int> fails = {};

    for (final climb in vClimbs) {
      final num = vGradeToNum(climb.gradeValue);
      if (num == null) continue;

      if (climb.sent) {
        sends[num] = (sends[num] ?? 0) + 1;
      } else {
        fails[num] = (fails[num] ?? 0) + 1;
      }
    }

    // Determine range: 0 to max grade present or V17
    int maxGrade = 0;
    for (final g in {...sends.keys, ...fails.keys}) {
      if (g > maxGrade) maxGrade = g;
    }
    // Always show at least V0-V2
    if (maxGrade < 2) maxGrade = 2;

    return List.generate(maxGrade + 1, (i) {
      return GradeDistributionPoint(
        gradeNum: i,
        gradeLabel: 'V$i',
        sends: sends[i] ?? 0,
        fails: fails[i] ?? 0,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Activity Heatmap
  // ---------------------------------------------------------------------------

  /// Returns daily climb counts for the heatmap.
  ///
  /// Groups climbs by calendar day. The result covers the full range from the
  /// earliest to latest climb date. Days with zero climbs are included so the
  /// heatmap grid is complete.
  List<HeatmapDay> activityHeatmap(List<Climb> climbs) {
    if (climbs.isEmpty) return [];

    final Map<DateTime, int> counts = {};
    DateTime earliest = climbs.first.loggedAt;
    DateTime latest = climbs.first.loggedAt;

    for (final climb in climbs) {
      final day = DateTime(climb.loggedAt.year, climb.loggedAt.month, climb.loggedAt.day);
      counts[day] = (counts[day] ?? 0) + 1;

      if (day.isBefore(earliest)) earliest = day;
      if (day.isAfter(latest)) latest = day;
    }

    // Fill in all days in the range
    final result = <HeatmapDay>[];
    for (var d = earliest; !d.isAfter(latest); d = d.add(const Duration(days: 1))) {
      result.add(HeatmapDay(
        date: d,
        climbCount: counts[d] ?? 0,
      ));
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Hardest Sends Over Time
  // ---------------------------------------------------------------------------

  /// Returns hardest send in each week for the progression chart.
  ///
  /// Groups climbs by ISO week. For each week, returns the highest V-grade
  /// that was sent. Weeks with no sends are skipped.
  List<ProgressionPoint> hardestSendsOverTime(List<Climb> climbs) {
    final sends = climbs.where((c) => c.sent && c.gradeSystem == 'V-scale');

    // Group by ISO week
    final Map<String, int> bestInWeek = {};
    final Map<String, DateTime> weekDate = {};

    for (final climb in sends) {
      final num = vGradeToNum(climb.gradeValue);
      if (num == null) continue;

      final monday = _mondayOf(climb.loggedAt);
      final key = '${monday.year}-W${_weekOfYear(monday)}';

      if (num > (bestInWeek[key] ?? -1)) {
        bestInWeek[key] = num;
        weekDate[key] = monday;
      }
    }

    if (bestInWeek.isEmpty) return [];

    // Sort by date
    final sorted = bestInWeek.entries.toList()
      ..sort((a, b) => weekDate[a.key]!.compareTo(weekDate[b.key]!));

    // Compute cumulative max
    final result = <ProgressionPoint>[];
    int runningMax = -1;
    for (final entry in sorted) {
      if (entry.value > runningMax) {
        runningMax = entry.value;
        result.add(ProgressionPoint(
          date: weekDate[entry.key]!,
          maxGrade: runningMax,
        ));
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Send Rate by Grade
  // ---------------------------------------------------------------------------

  /// Returns send rate (percentage) for each grade.
  ///
  /// Only includes grades with at least [minAttempts] total attempts
  /// to avoid noisy rates from single climbs.
  List<SendRatePoint> sendRateByGrade(List<Climb> climbs, {int minAttempts = 1}) {
    final vClimbs = climbs.where((c) => c.gradeSystem == 'V-scale');

    final Map<int, int> sends = {};
    final Map<int, int> total = {};

    for (final climb in vClimbs) {
      final num = vGradeToNum(climb.gradeValue);
      if (num == null) continue;

      if (climb.sent) {
        sends[num] = (sends[num] ?? 0) + 1;
      }
      total[num] = (total[num] ?? 0) + climb.attempts;
    }

    final result = <SendRatePoint>[];
    for (final entry in total.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
      if (entry.value < minAttempts) continue;
      result.add(SendRatePoint(
        gradeLabel: 'V${entry.key}',
        sendRate: sends[entry.key] != null ? (sends[entry.key]! / entry.value) : 0.0,
        totalAttempts: entry.value,
      ));
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Style Bias Heatmap (MVP: per-tag send rates)
  // ---------------------------------------------------------------------------

  /// Returns send rate per tag (climbing style).
  ///
  /// Takes climbs and their associated tags. A climb's send/fail contributes
  /// to each tag attached to it.
  List<StyleBiasPoint> styleBiasHeatmap(
    List<Climb> climbs,
    Map<int, List<Tag>> climbTags,
  ) {
    final Map<String, int> sends = {};
    final Map<String, int> total = {};

    for (final climb in climbs) {
      final tags = climbTags[climb.id];
      if (tags == null || tags.isEmpty) continue;

      for (final tag in tags) {
        if (climb.sent) {
          sends[tag.name] = (sends[tag.name] ?? 0) + 1;
        }
        total[tag.name] = (total[tag.name] ?? 0) + 1;
      }
    }

    final result = <StyleBiasPoint>[];
    for (final entry in total.entries) {
      result.add(StyleBiasPoint(
        tagName: entry.key,
        sendRate: sends[entry.key] != null ? (sends[entry.key]! / entry.value) : 0.0,
        totalClimbs: entry.value,
      ));
    }

    // Sort by send rate ascending (weakest first)
    result.sort((a, b) => a.sendRate.compareTo(b.sendRate));
    return result;
  }

  // ---------------------------------------------------------------------------
  // Date helpers
  // ---------------------------------------------------------------------------

  /// Returns the Monday of the week containing [date].
  static DateTime _mondayOf(DateTime date) {
    return DateTime(date.year, date.month, date.day - date.weekday + 1);
  }

  /// Returns the ISO week number for [date].
  static int _weekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final days = date.difference(firstDayOfYear).inDays;
    return ((days + firstDayOfYear.weekday) ~/ 7) + 1;
  }
}
