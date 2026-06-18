import 'package:flutter/material.dart';

import '../../../domain/services/performance_service.dart';

/// Card list showing the user's style weaknesses with recommendations.
///
/// Each card shows a tag style where the user's send rate is >25% below
/// their average for the same grade range, with a color-coded severity
/// indicator and a human-readable training recommendation.
class WeaknessPrescriptionCard extends StatelessWidget {
  const WeaknessPrescriptionCard({
    super.key,
    required this.data,
  });

  final List<WeaknessPrescription> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text(
        'No significant weaknesses detected. Log more tagged climbs to get '
        'personalized recommendations.',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'These styles have the lowest send rates relative to your '
            'average at similar grades. Focus on what you avoid.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ),
        ...data.map(_PrescriptionRow.new),
      ],
    );
  }
}

class _PrescriptionRow extends StatelessWidget {
  const _PrescriptionRow(this.prescription);

  final WeaknessPrescription prescription;

  @override
  Widget build(BuildContext context) {
    final severity = _severityInfo(prescription.deficitPercent);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: severity.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: tag name + severity badge
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: severity.badgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    prescription.tagName.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    severity.label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Stats row
            Row(
              children: [
                _StatBox(
                  label: 'Your Rate',
                  value:
                      '${(prescription.userSendRate * 100).toStringAsFixed(0)}%',
                  color: Colors.red.shade600,
                ),
                const SizedBox(width: 12),
                _StatBox(
                  label: 'Average',
                  value:
                      '${(prescription.averageSendRate * 100).toStringAsFixed(0)}%',
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 12),
                _StatBox(
                  label: 'Gap',
                  value:
                      '-${prescription.deficitPercent.toStringAsFixed(0)}%',
                  color: Colors.red.shade700,
                ),
                const Spacer(),
                Text(
                  '${prescription.totalClimbs} climbs',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Recommendation text
            Text(
              prescription.recommendation,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Severity info for the deficit percentage.
_SeverityInfo _severityInfo(double deficitPercent) {
  if (deficitPercent > 50) {
    return const _SeverityInfo(
      label: 'Major Weakness',
      badgeColor: Color(0xFFC62828),
      backgroundColor: Color(0xFFFFF0F0),
    );
  } else if (deficitPercent > 35) {
    return const _SeverityInfo(
      label: 'Notable Weakness',
      badgeColor: Color(0xFFE65100),
      backgroundColor: Color(0xFFFFF3E0),
    );
  }
  return const _SeverityInfo(
    label: 'Slight Weakness',
    badgeColor: Color(0xFFF57F17),
    backgroundColor: Color(0xFFFFF8E1),
  );
}

class _SeverityInfo {
  final String label;
  final Color badgeColor;
  final Color backgroundColor;

  const _SeverityInfo({
    required this.label,
    required this.badgeColor,
    required this.backgroundColor,
  });
}
