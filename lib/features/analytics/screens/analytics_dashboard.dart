import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/services/analytics_service.dart';
import '../providers/analytics_providers.dart';
import '../widgets/grade_pyramid_chart.dart';
import '../widgets/activity_heatmap.dart';
import '../widgets/hardest_sends_chart.dart';
import '../widgets/send_rate_chart.dart';
import '../widgets/peak_window_chart.dart';
import '../widgets/fatigue_chart.dart';
import '../widgets/weakness_prescription_card.dart';

class AnalyticsDashboard extends ConsumerWidget {
  const AnalyticsDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Grade Pyramid ──────────────────────────────────────────────
          _SectionCard(
            title: 'Grade Pyramid',
            subtitle: 'Sends vs. fails by grade',
            child: ref.watch(gradeDistributionProvider).when(
                  data: (data) => GradePyramidChart(data: data),
                  loading: () => const _LoadingIndicator(),
                  error: (err, _) => _ErrorText('$err'),
                ),
          ),
          const SizedBox(height: 12),

          // ── Activity Heatmap ───────────────────────────────────────────
          _SectionCard(
            title: 'Activity Heatmap',
            subtitle: 'Daily climbing frequency',
            child: ref.watch(activityHeatmapProvider).when(
                  data: (data) => ActivityHeatmap(data: data),
                  loading: () => const _LoadingIndicator(),
                  error: (err, _) => _ErrorText('$err'),
                ),
          ),
          const SizedBox(height: 12),

          // ── Hardest Sends ──────────────────────────────────────────────
          _SectionCard(
            title: 'Progression',
            subtitle: 'Hardest sends over time',
            child: ref.watch(hardestSendsProvider).when(
                  data: (data) => HardestSendsChart(data: data),
                  loading: () => const _LoadingIndicator(),
                  error: (err, _) => _ErrorText('$err'),
                ),
          ),
          const SizedBox(height: 12),

          // ── Send Rate by Grade ─────────────────────────────────────────
          _SectionCard(
            title: 'Send Rate by Grade',
            subtitle: 'Success rate at each grade',
            child: ref.watch(sendRateProvider).when(
                  data: (data) => SendRateChart(data: data),
                  loading: () => const _LoadingIndicator(),
                  error: (err, _) => _ErrorText('$err'),
                ),
          ),
          const SizedBox(height: 12),

          // ── Style Bias ─────────────────────────────────────────────────
          _SectionCard(
            title: 'Style Bias',
            subtitle: 'Send rate by climbing style',
            child: ref.watch(styleBiasProvider).when(
                  data: (data) => _StyleBiasList(data: data),
                  loading: () => const _LoadingIndicator(),
                  error: (err, _) => _ErrorText('$err'),
                ),
          ),
          const SizedBox(height: 12),

          // ── Performance ───────────────────────────────────────────────
          const _SectionHeader(title: 'Performance'),

          // ── Weakness Prescription ─────────────────────────────────────
          _SectionCard(
            title: 'Weakness Prescription',
            subtitle: 'Styles you should train more',
            child: ref.watch(weaknessPrescriptionProvider).when(
                  data: (data) => WeaknessPrescriptionCard(data: data),
                  loading: () => const _LoadingIndicator(),
                  error: (err, _) => _ErrorText('$err'),
                ),
          ),
          const SizedBox(height: 12),

          // ── Peak Window ───────────────────────────────────────────────
          _SectionCard(
            title: 'Peak Performance Window',
            subtitle: 'When you climb best during the day',
            child: ref.watch(peakWindowProvider).when(
                  data: (data) => PeakWindowChart(data: data),
                  loading: () => const _LoadingIndicator(),
                  error: (err, _) => _ErrorText('$err'),
                ),
          ),
          const SizedBox(height: 12),

          // ── Fatigue Trend ─────────────────────────────────────────────
          _SectionCard(
            title: 'Session Fatigue Curve',
            subtitle: 'How RPE rises as your session progresses',
            child: ref.watch(fatigueTrendProvider).when(
                  data: (data) => FatigueChart(data: data),
                  loading: () => const _LoadingIndicator(),
                  error: (err, _) => _ErrorText('$err'),
                ),
          ),
        ],
      ),
    );
  }
}

/// Renders style bias as a simple list of colored bars (no fl_chart needed).
class _StyleBiasList extends StatelessWidget {
  const _StyleBiasList({required this.data});

  final List<StyleBiasPoint> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text(
        'Log tagged climbs to see your style bias',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      );
    }

    return Column(
      children: data.map((point) {
        Color barColor;
        if (point.sendRate < 0.33) {
          barColor = const Color(0xFFEF5350);
        } else if (point.sendRate < 0.66) {
          barColor = const Color(0xFFFFC107);
        } else {
          barColor = const Color(0xFF4CAF50);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  point.tagName,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: point.sendRate,
                    minHeight: 18,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: Text(
                  '${(point.sendRate * 100).toStringAsFixed(0)}% (${point.totalClimbs})',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.red, fontSize: 13),
        ),
      ),
    );
  }
}
