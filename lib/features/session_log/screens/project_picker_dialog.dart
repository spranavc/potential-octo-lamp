import 'package:flutter/material.dart';

import '../../../data/repositories/project_repository.dart';

/// A multi-select dialog that lets the user pick one or more active projects
/// to assign climbs to, or create a new project inline.
///
/// Returns a list of selected [projectId]s, or null if the user cancels.
class ProjectPickerDialog extends StatefulWidget {
  const ProjectPickerDialog({
    super.key,
    required this.gymId,
    required this.projectRepository,
    this.initialSelectedIds = const [],
  });

  final int gymId;
  final ProjectRepository projectRepository;
  final List<int> initialSelectedIds;

  @override
  State<ProjectPickerDialog> createState() => _ProjectPickerDialogState();
}

class _ProjectPickerDialogState extends State<ProjectPickerDialog> {
  late List<int> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List<int>.from(widget.initialSelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.rocket_launch, size: 22),
          const SizedBox(width: 8),
          Text('Assign to Projects', style: theme.textTheme.titleMedium),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder(
          future: widget.projectRepository.getAll(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final projects = snapshot.data ?? [];
            final activeProjects =
                projects.where((p) => p.status == 'active').toList();

            if (activeProjects.isEmpty && projects.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.rocket_launch, size: 48,
                        color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'No projects yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Create your first project to start tracking a specific climb.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _showCreateProjectDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create Project'),
                    ),
                  ],
                ),
              );
            }

            if (activeProjects.isEmpty && projects.isNotEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'All projects are completed or abandoned.\nCreate a new one to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Active Projects',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...activeProjects.map(
                  (project) {
                    final isSelected = _selectedIds.contains(project.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      color: isSelected
                          ? theme.colorScheme.primaryContainer.withAlpha(80)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.grey.shade200,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(project.id);
                            } else {
                              _selectedIds.add(project.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.rocket_launch,
                                  size: 20, color: Colors.deepOrange),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      project.name,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '${project.gradeSystem} ${project.gradeValue}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle,
                                    color: theme.colorScheme.primary, size: 22)
                              else
                                Icon(Icons.circle_outlined,
                                    color: Colors.grey.shade300, size: 22),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      actions: [
        Center(
          child: Wrap(
            spacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showCreateProjectDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_selectedIds),
                child: Text(_selectedIds.isEmpty
                    ? 'Skip'
                    : 'Done (${_selectedIds.length})'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  void _showCreateProjectDialog(BuildContext context) {
    final nameController = TextEditingController();
    final gradeSystemController = TextEditingController(text: 'V-scale');
    final gradeValueController = TextEditingController(text: 'V4');
    final descController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Project'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  hintText: 'e.g. "The Pink One in the Cave"',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: gradeSystemController,
                      decoration: const InputDecoration(
                        labelText: 'Grade System',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: gradeValueController,
                      decoration: const InputDecoration(
                        labelText: 'Grade Value',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              try {
                final id = await widget.projectRepository.create(
                  gymId: widget.gymId,
                  name: name,
                  gradeSystem: gradeSystemController.text.trim(),
                  gradeValue: gradeValueController.text.trim(),
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
                setState(() {
                  _selectedIds.add(id);
                });
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text('Failed to create project: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
