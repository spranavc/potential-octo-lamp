import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';
import '../../gyms/providers/gym_providers.dart';
import '../../sync/providers/sync_providers.dart';
import '../providers/project_providers.dart';
import '../widgets/project_card.dart';

class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key});

  Future<void> _addProject(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_AddProjectResult>(
      context: context,
      builder: (ctx) => const _AddProjectDialog(),
    );
    if (result != null && result.name.trim().isNotEmpty) {
      final repo = ref.read(projectRepositoryProvider);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await repo.create(
        gymId: result.gymId,
        name: result.name.trim(),
        gradeSystem: result.gradeSystem,
        gradeValue: result.gradeValue,
        description: result.description?.trim(),
        userId: userId,
      );
      ref.invalidate(projectListProvider);
      triggerPushSync(ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: projectsAsync.when(
        data: (projects) {
          if (projects.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No projects yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Create a project to track a specific climb', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return Dismissible(
                key: Key('project-${project.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) => _confirmDeleteProject(context, ref, project),
                onDismissed: (_) => _deleteProject(ref, project),
                child: ProjectCard(
                  project: project,
                  onTap: () => context.go('/session-log/projects/${project.id}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-project',
        onPressed: () => _addProject(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Project'),
      ),
    );
  }
}

Future<bool> _confirmDeleteProject(BuildContext context, WidgetRef ref, Project project) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Project'),
          content: Text(
              'Delete "${project.name}" '
              '(${project.gradeSystem} ${project.gradeValue})? All linked climbs will be unlinked. This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> _deleteProject(WidgetRef ref, Project project) async {
  final repo = ref.read(projectRepositoryProvider);
  await repo.delete(project.id);
  ref.invalidate(projectListProvider);
}

class _AddProjectResult {
  const _AddProjectResult({
    required this.gymId,
    required this.name,
    required this.gradeSystem,
    required this.gradeValue,
    this.description,
  });

  final int gymId;
  final String name;
  final String gradeSystem;
  final String gradeValue;
  final String? description;
}

class _AddProjectDialog extends ConsumerStatefulWidget {
  const _AddProjectDialog();

  @override
  ConsumerState<_AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends ConsumerState<_AddProjectDialog> {
  final _nameController = TextEditingController();
  final _gradeValueController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _selectedGymId;
  String _gradeSystem = 'V-scale';

  @override
  void dispose() {
    _nameController.dispose();
    _gradeValueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gymsAsync = ref.watch(gymListProvider);

    return AlertDialog(
      title: const Text('New Project'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Project name',
                hintText: 'e.g. "The Pink One in the Cave"',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            gymsAsync.when(
              data: (gyms) => DropdownButtonFormField<int>(
                initialValue: _selectedGymId,
                decoration: const InputDecoration(
                  labelText: 'Gym',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Select a gym'),
                isExpanded: true,
                items: gyms.map((gym) {
                  return DropdownMenuItem<int>(
                    value: gym.id,
                    child: Text(gym.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedGymId = value);
                },
              ),
              loading: () => const Text('Loading gyms...'),
              error: (err, _) => Text('Error: $err'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _gradeSystem,
              decoration: const InputDecoration(
                labelText: 'Grade system',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'V-scale', child: Text('V-scale')),
                DropdownMenuItem(value: 'Font', child: Text('Font')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _gradeSystem = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gradeValueController,
              decoration: InputDecoration(
                labelText: 'Grade',
                hintText: _gradeSystem == 'V-scale' ? 'e.g. V5' : 'e.g. 7A',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty ||
                _selectedGymId == null ||
                _gradeValueController.text.trim().isEmpty) {
              return;
            }
            Navigator.of(context).pop(_AddProjectResult(
              gymId: _selectedGymId!,
              name: _nameController.text,
              gradeSystem: _gradeSystem,
              gradeValue: _gradeValueController.text,
              description: _descriptionController.text.isEmpty
                  ? null
                  : _descriptionController.text,
            ));
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
