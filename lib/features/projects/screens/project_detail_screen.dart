import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/project_providers.dart';
import '../widgets/project_progress_bar.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));
    final climbsAsync = ref.watch(projectClimbsProvider(projectId));
    final progressAsync = ref.watch(projectProgressProvider(projectId));

    return projectAsync.when(
      data: (project) {
        if (project == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Project')),
            body: const Center(child: Text('Project not found')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(project.name),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Project info ──────────────────────────────────────────
              _DetailRow(label: 'Grade', value: '${project.gradeSystem} ${project.gradeValue}'),
              _DetailRow(label: 'Status', value: _statusText(project.status)),
              if (project.description != null && project.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  project.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
              ],
              if (project.startedAt != null)
                _DetailRow(
                  label: 'Started',
                  value: _formatDate(project.startedAt!),
                ),
              if (project.completedAt != null)
                _DetailRow(
                  label: 'Completed',
                  value: _formatDate(project.completedAt!),
                ),
              const SizedBox(height: 16),

              // ── Progress bar ──────────────────────────────────────────
              progressAsync.when(
                data: (progress) => ProjectProgressBar(
                  sentClimbs: progress.sentClimbs,
                  totalClimbs: progress.totalClimbs,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text('Error: $err'),
              ),
              const SizedBox(height: 24),

              // ── Attached climbs ───────────────────────────────────────
              Text('Climbs', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              climbsAsync.when(
                data: (climbs) {
                  if (climbs.isEmpty) {
                    return const Text(
                      'No climbs attached to this project yet.',
                      style: TextStyle(color: Colors.grey),
                    );
                  }
                  return Column(
                    children: climbs.map((climb) {
                      final date =
                          '${climb.loggedAt.month}/${climb.loggedAt.day}/${climb.loggedAt.year}';
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          climb.sent ? Icons.check_circle : Icons.cancel,
                          color: climb.sent ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        title: Text('${climb.gradeSystem} ${climb.gradeValue}'),
                        subtitle: Text(
                          '${climb.sent ? "Sent" : "Failed"} · ${climb.attempts} ${_pluralize(climb.attempts, "attempt")}  —  $date',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error: $err'),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Project')),
        body: Center(child: Text('Error: $err')),
      ),
    );
  }
}

String _statusText(String status) {
  switch (status) {
    case 'completed':
      return 'Completed';
    case 'abandoned':
      return 'Abandoned';
    default:
      return 'Active';
  }
}

String _formatDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year}';
}

String _pluralize(int count, String word) {
  return count == 1 ? word : '${word}s';
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
