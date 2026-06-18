import '../../data/database/database.dart';
import 'analytics_service.dart';

// ---------------------------------------------------------------------------
// Data transfer objects
// ---------------------------------------------------------------------------

/// A point on the session performance curve: climb order vs. grade success.
class SessionPerformancePoint {
  final int climbOrder; // 1-based position within the session
  final int gradeNum; // numeric grade of the climb
  final bool sent; // whether the climb was successful
  final String gradeLabel;

  const SessionPerformancePoint({
    required this.climbOrder,
    required this.gradeNum,
    required this.sent,
    required this.gradeLabel,
  });
}

/// Rolling average point for the session performance trend line.
class RollingAveragePoint {
  final int climbOrder;
  final double averageGrade;

  const RollingAveragePoint({
    required this.climbOrder,
    required this.averageGrade,
  });
}

/// Peak window data — best send rate by hour-of-day buckets.
class PeakWindowBucket {
  final String label; // e.g. "6-8 AM", "6-8 PM"
  final int hourStart; // inclusive
  final int hourEnd; // exclusive
  final double sendRate;
  final int totalClimbs;

  const PeakWindowBucket({
    required this.label,
    required this.hourStart,
    required this.hourEnd,
    required this.sendRate,
    required this.totalClimbs,
  });
}

/// Fatigue data point: RPE over time within a session.
class FatiguePoint {
  final int climbOrder; // 1-based position
  final double rpe; // 1-10 RPE value

  const FatiguePoint({
    required this.climbOrder,
    required this.rpe,
  });
}

/// Weakness prescription: a style where the user underperforms.
class WeaknessPrescription {
  final String tagName;
  final double userSendRate;
  final double averageSendRate; // average for the same grade range
  final double deficitPercent; // how far below average (positive => weakness)
  final int totalClimbs;
  final String recommendation; // human-readable suggestion

  const WeaknessPrescription({
    required this.tagName,
    required this.userSendRate,
    required this.averageSendRate,
    required this.deficitPercent,
    required this.totalClimbs,
    required this.recommendation,
  });
}

// ---------------------------------------------------------------------------
// PerformanceService
// ---------------------------------------------------------------------------

/// Pure computation service for performance analytics.
///
/// All methods accept raw data (lists of climbs, sessions, tags) and return
/// computed results. No database queries — callers provide the data.
class PerformanceService {
  const PerformanceService();

  // ---------------------------------------------------------------------------
  // Session Performance Curve
  // ---------------------------------------------------------------------------

  /// Computes the session performance curve for a given session.
  ///
  /// Each climb is plotted by its order (1st, 2nd, 3rd...) on the X axis and
  /// its grade number on the Y axis. Sends and fails are distinguished so the
  /// chart can show send/fail markers differently, and a rolling average trend
  /// line is computed to reveal the performance curve shape.
  ///
  /// [climbs] must be sorted by loggedAt ascending (climb order within session).
  List<SessionPerformancePoint> sessionPerformanceCurve(List<Climb> climbs) {
    final result = <SessionPerformancePoint>[];
    for (var i = 0; i < climbs.length; i++) {
      final climb = climbs[i];
      final gradeNum =
          AnalyticsService.gradeToNum(climb.gradeSystem, climb.gradeValue);
      if (gradeNum == null) continue;

      result.add(SessionPerformancePoint(
        climbOrder: i + 1,
        gradeNum: gradeNum,
        sent: climb.sent,
        gradeLabel: climb.gradeValue,
      ));
    }
    return result;
  }

  /// Computes a rolling average over [points] using [windowSize].
  ///
  /// Returns a list of [RollingAveragePoint] representing the smoothed trend
  /// of grade send success. Each point averages the grade number of successful
  /// climbs within the window centered on that climb order.
  List<RollingAveragePoint> rollingAverageTrend(
    List<SessionPerformancePoint> points, {
    int windowSize = 3,
  }) {
    if (points.isEmpty) return [];

    // Build a signal: for each point, the grade if sent, else null (gap).
    // We compute a rolling average over the sent-grade values.
    final sentGrades = points.map((p) => p.sent ? p.gradeNum : -1).toList();

    final result = <RollingAveragePoint>[];
    for (var i = 0; i < points.length; i++) {
      var sum = 0;
      var count = 0;
      for (var j = i - windowSize + 1; j <= i; j++) {
        if (j >= 0 && j < sentGrades.length && sentGrades[j] >= 0) {
          sum += sentGrades[j];
          count++;
        }
      }
      if (count > 0) {
        result.add(RollingAveragePoint(
          climbOrder: points[i].climbOrder,
          averageGrade: sum / count,
        ));
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Peak Window (best send rate by time of day)
  // ---------------------------------------------------------------------------

  /// Computes peak performance windows across all sessions.
  ///
  /// Groups climbs into 2-hour buckets by their loggedAt hour of day and
  /// calculates the send rate for each bucket. The buckets with the highest
  /// send rates represent the user's peak performance windows.
  ///
  /// Only buckets with at least [minClimbs] climbs are included.
  List<PeakWindowBucket> peakWindow(
    List<Climb> climbs, {
    int minClimbs = 3,
  }) {
    if (climbs.isEmpty) return [];

    // 12 two-hour buckets covering the full 24-hour day
    final buckets = List.generate(12, (i) {
      final start = i * 2;
      final end = start + 2;
      final hourLabel = _hourRangeLabel(start, end);
      return PeakWindowBucket(
        label: hourLabel,
        hourStart: start,
        hourEnd: end,
        sendRate: 0,
        totalClimbs: 0,
      );
    });

    final sendsPerBucket = List.filled(12, 0);
    final totalPerBucket = List.filled(12, 0);

    for (final climb in climbs) {
      final hour = climb.loggedAt.hour;
      final bucketIndex = hour ~/ 2; // 0..11
      if (bucketIndex < 0 || bucketIndex >= 12) continue;

      if (climb.sent) {
        sendsPerBucket[bucketIndex]++;
      }
      totalPerBucket[bucketIndex]++;
    }

    final result = <PeakWindowBucket>[];
    for (var i = 0; i < 12; i++) {
      if (totalPerBucket[i] < minClimbs) continue;
      result.add(PeakWindowBucket(
        label: buckets[i].label,
        hourStart: buckets[i].hourStart,
        hourEnd: buckets[i].hourEnd,
        sendRate: totalPerBucket[i] > 0
            ? sendsPerBucket[i] / totalPerBucket[i]
            : 0,
        totalClimbs: totalPerBucket[i],
      ));
    }

    // Sort by send rate descending (best first)
    result.sort((a, b) => b.sendRate.compareTo(a.sendRate));
    return result;
  }

  // ---------------------------------------------------------------------------
  // Fatigue Trend
  // ---------------------------------------------------------------------------

  /// Computes fatigue trend across all sessions.
  ///
  /// [climbs] must be sorted by session, then by loggedAt within each session.
  /// The method numbers climbs within each session and computes average RPE per
  /// position. Requires at least [minSessions] sessions contributing to a
  /// position for it to be included in the result.
  List<FatiguePoint> fatigueTrendGrouped(
    List<Climb> climbs, {
    int minSessions = 2,
  }) {
    if (climbs.isEmpty) return [];

    // Group climbs by session and assign intra-session order
    final Map<int, List<Climb>> sessions = {};
    for (final climb in climbs) {
      sessions.putIfAbsent(climb.sessionId, () => []);
      sessions[climb.sessionId]!.add(climb);
    }

    // Sort climbs within each session by loggedAt
    for (final sessionClimbs in sessions.values) {
      sessionClimbs.sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    }

    // Collect RPE by climb position within session
    final Map<int, int> sessionCountByPosition = {};
    final Map<int, double> rpeSumByPosition = {};

    for (final sessionClimbs in sessions.values) {
      for (var i = 0; i < sessionClimbs.length; i++) {
        final climb = sessionClimbs[i];
        if (climb.rpe == null) continue;

        final position = i + 1;
        sessionCountByPosition[position] =
            (sessionCountByPosition[position] ?? 0) + 1;
        rpeSumByPosition[position] =
            (rpeSumByPosition[position] ?? 0) + climb.rpe!;
      }
    }

    final result = <FatiguePoint>[];
    for (final entry in sessionCountByPosition.entries) {
      if (entry.value < minSessions) continue;
      result.add(FatiguePoint(
        climbOrder: entry.key,
        rpe: rpeSumByPosition[entry.key]! / entry.value,
      ));
    }

    result.sort((a, b) => a.climbOrder.compareTo(b.climbOrder));
    return result;
  }

  // ---------------------------------------------------------------------------
  // Weakness Prescription
  // ---------------------------------------------------------------------------

  /// Identifies climb styles (tags) where the user's send rate is significantly
  /// below their average for climbs of comparable grade.
  ///
  /// For each tag, compares the user's send rate against their overall send rate
  /// for climbs in the same grade range (±[gradeRange] around the average grade
  /// of climbs with that tag). Tags where the user's send rate is more than
  /// [thresholdPercent] below the grade-range average are flagged as weaknesses.
  ///
  /// Returns prescriptions sorted by deficit (largest weakness first).
  List<WeaknessPrescription> weaknessPrescription(
    List<Climb> climbs,
    Map<int, List<Tag>> climbTags, {
    int gradeRange = 2,
    double thresholdPercent = 0.25,
  }) {
    if (climbs.isEmpty) return [];

    // Build a lookup table for each climb's grade number and tags
    final Map<int, int> climbGrade = {};
    final Map<int, List<String>> climbTagNames = {};

    for (final climb in climbs) {
      final num =
          AnalyticsService.gradeToNum(climb.gradeSystem, climb.gradeValue);
      if (num == null) continue;
      climbGrade[climb.id] = num;
      climbTagNames[climb.id] =
          (climbTags[climb.id] ?? []).map((t) => t.name).toList();
    }

    // For each tag, compute average grade of climbs with that tag
    // and the user's send rate for that tag.
    final Map<String, List<int>> tagGrades = {}; // grades tagged with this style
    final Map<String, int> tagSends = {};
    final Map<String, int> tagTotal = {};

    for (final climb in climbs) {
      final grade = climbGrade[climb.id];
      if (grade == null) continue;

      final tags = climbTagNames[climb.id] ?? [];
      for (final tag in tags) {
        tagGrades.putIfAbsent(tag, () => []);
        tagGrades[tag]!.add(grade);

        if (climb.sent) {
          tagSends[tag] = (tagSends[tag] ?? 0) + 1;
        }
        tagTotal[tag] = (tagTotal[tag] ?? 0) + 1;
      }
    }

    final result = <WeaknessPrescription>[];

    for (final entry in tagTotal.entries) {
      final tagName = entry.key;
      final tagSendRate = (tagSends[tagName] ?? 0) / entry.value;
      final grades = tagGrades[tagName]!;
      final avgGrade =
          grades.reduce((a, b) => a + b) / grades.length.toDouble();

      // Determine grade range for comparison
      final minGrade = (avgGrade - gradeRange).clamp(0, 17).toInt();
      final maxGrade = (avgGrade + gradeRange).clamp(0, 17).toInt();

      // Compute average send rate for all climbs in this grade range
      var rangeSends = 0;
      var rangeTotal = 0;
      for (final climb in climbs) {
        final g = climbGrade[climb.id];
        if (g == null) continue;
        if (g < minGrade || g > maxGrade) continue;

        if (climb.sent) rangeSends++;
        rangeTotal++;
      }

      final averageSendRate =
          rangeTotal > 0 ? rangeSends / rangeTotal : 0.0;
      final deficit = averageSendRate - tagSendRate;

      // Only flag as weakness if the deficit exceeds the threshold
      if (deficit > thresholdPercent && averageSendRate > 0) {
        final deficitPct = (deficit / averageSendRate) * 100;
        result.add(WeaknessPrescription(
          tagName: tagName,
          userSendRate: tagSendRate,
          averageSendRate: averageSendRate,
          deficitPercent: deficitPct,
          totalClimbs: entry.value,
          recommendation:
              _buildRecommendation(tagName, deficitPct, tagSendRate),
        ));
      }
    }

    // Sort by deficit descending (biggest weakness first)
    result.sort((a, b) => b.deficitPercent.compareTo(a.deficitPercent));
    return result;
  }

  /// Generates a human-readable recommendation for a weakness.
  String _buildRecommendation(
      String tagName, double deficitPercent, double sendRate) {
    final deficitStr = deficitPercent.toStringAsFixed(0);
    final currentStr = (sendRate * 100).toStringAsFixed(0);

    if (deficitPercent > 50) {
      return 'Major weakness: $tagName climbs ($currentStr% vs. '
          'average peers at same grade). Prioritize 2-3 $tagName '
          'climbs per session.';
    } else if (deficitPercent > 35) {
      return 'Notable weakness: $currentStr% send rate on $tagName '
          '($deficitStr% below average). Add $tagName problems '
          'to your warmup routine.';
    }
    return 'Slight weakness: $currentStr% on $tagName '
        '($deficitStr% below average). Mix in more $tagName climbs '
        'to build confidence.';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _hourRangeLabel(int start, int end) {
    final startPeriod = start < 12 ? 'AM' : 'PM';
    final endPeriod = end <= 12 ? 'AM' : 'PM';
    final startHour = start == 0 ? 12 : (start > 12 ? start - 12 : start);
    final endHour = end == 24 ? 12 : (end > 12 ? end - 12 : end);
    return '$startHour $startPeriod - $endHour $endPeriod';
  }
}
