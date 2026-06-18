import 'package:flutter/material.dart';

import '../../../data/database/database.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({super.key, required this.project, this.onTap});

  final Project project;
  final VoidCallback? onTap;

  String get _statusLabel {
    switch (project.status) {
      case 'completed':
        return 'Completed';
      case 'abandoned':
        return 'Abandoned';
      default:
        return 'Active';
    }
  }

  Color get _statusColor {
    switch (project.status) {
      case 'completed':
        return Colors.green;
      case 'abandoned':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.rocket_launch,
          color: _statusColor,
        ),
        title: Text(project.name),
        subtitle: Text(
          '${project.gradeSystem} ${project.gradeValue}  ·  $_statusLabel',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
