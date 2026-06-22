import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:url_launcher/url_launcher.dart';

import '../../../data/database/database.dart';
import '../../../data/providers/database_provider.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../shared/utils/time_format.dart';
import '../../projects/providers/project_providers.dart';
import '../../sync/providers/sync_providers.dart';
import '../providers/gym_providers.dart';

class GymDetailScreen extends ConsumerWidget {
  const GymDetailScreen({super.key, required this.gymId});

  final int gymId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymAsync = ref.watch(gymDetailProvider(gymId));
    final directoryGyms = ref.watch(directoryGymsProvider).valueOrNull;
    final sessionsAsync = ref.watch(gymSessionsProvider(gymId));
    final projectsAsync = ref.watch(_gymProjectsProvider(gymId));

    return gymAsync.when(
      data: (gym) {
        final displayGym = gym ?? directoryGyms?.where((g) => g.id == gymId).firstOrNull;
        if (displayGym == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Gym')),
            body: const Center(child: Text('Gym not found')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(displayGym.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Rename gym',
                onPressed: () => _renameGym(context, ref, displayGym.name),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete gym',
                onPressed: () => _deleteGym(context, ref, displayGym.name),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Start session button ─────────────────────────────────
              FilledButton.icon(
                onPressed: () => context.go('/session-log/active'),
                icon: const Icon(Icons.sports_kabaddi),
                label: const Text('Start Session Here'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 16),

              // ── Rich metadata for directory gyms ──────────────────────
              if (_hasRichMetadata(displayGym)) ...[
                if (displayGym.isDirectory && displayGym.userId == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FilledButton.icon(
                      onPressed: () => _addToMyGyms(context, ref, displayGym),
                      icon: const Icon(Icons.add),
                      label: const Text('Add to My Gyms'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                      ),
                    ),
                  ),
                if (displayGym.description != null &&
                    displayGym.description!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(displayGym.description!,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                _InfoSection(
                  children: [
                    if (displayGym.rating != null)
                      _InfoRow(
                        icon: Icons.star,
                        label: '${displayGym.rating!.toStringAsFixed(1)} (${displayGym.ratingCount ?? 0} reviews)',
                        color: Colors.amber,
                      ),
                    if (displayGym.address != null &&
                        displayGym.address!.trim().isNotEmpty)
                      _InfoRow(
                        icon: Icons.location_on,
                        label: displayGym.address!,
                        onTap: () => _openMaps(displayGym.address!),
                      ),
                    if (displayGym.dayPassPrice != null &&
                        displayGym.dayPassPrice!.trim().isNotEmpty)
                      _InfoRow(
                        icon: Icons.confirmation_number,
                        label: 'Day Pass: ${displayGym.dayPassPrice!}',
                      ),
                    if (displayGym.phone != null &&
                        displayGym.phone!.trim().isNotEmpty)
                      _InfoRow(
                        icon: Icons.phone,
                        label: displayGym.phone!,
                        onTap: () => launchUrl(Uri.parse('tel:${displayGym.phone!}')),
                      ),
                    if (displayGym.website != null &&
                        displayGym.website!.trim().isNotEmpty)
                      _InfoRow(
                        icon: Icons.language,
                        label: displayGym.website!,
                        onTap: () => _openUrl(displayGym.website!),
                      ),
                    if (displayGym.hours != null &&
                        displayGym.hours!.trim().isNotEmpty)
                      _InfoRow(
                        icon: Icons.access_time,
                        label: displayGym.hours!,
                      ),
                  ],
                ),
                _AmenitiesSection(gym: displayGym),
                const Divider(height: 24),
              ],

              // ── Projects section ──────────────────────────────────────
              const _SectionHeader(title: 'Active Projects'),
              projectsAsync.when(
                data: (projects) {
                  if (projects.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text('No active projects at this gym',
                          style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: projects
                          .map((p) => _ProjectCard(
                                project: p,
                                onTap: () => context
                                    .push('/session-log/projects/${p.id}'),
                              ))
                          .toList(),
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
                error: (err, _) => Text('Error: $err'),
              ),

              // ── Completed Projects ───────────────────────────────────
              _CompletedProjectsSection(gymId: gymId),

              // ── Recent sessions section ───────────────────────────────
              const _SectionHeader(title: 'Recent Sessions'),
              sessionsAsync.when(
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return const Text('No sessions at this gym yet',
                        style: TextStyle(color: Colors.grey));
                  }
                  return Column(
                    children: sessions.take(10).map((s) {
                      final date = formatDateFull(s.startedAt);
                      final time = formatTime(s.startedAt);
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.sports_kabaddi, size: 20),
                        title: Text(date),
                        subtitle: Text(
                          s.endedAt != null ? 'Completed · Started $time' : 'In progress · Started $time',
                          style: TextStyle(
                            color: s.endedAt != null ? Colors.green : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => context.go('/session-log/${s.id}'),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
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
        appBar: AppBar(title: const Text('Gym')),
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  Future<void> _renameGym(BuildContext context, WidgetRef ref, String currentName) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: currentName);
        return AlertDialog(
          title: const Text('Rename Gym'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Gym name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
    if (name != null && name.trim().isNotEmpty) {
      final repo = ref.read(gymRepositoryProvider);
      await repo.updateName(gymId, name.trim());
      ref.invalidate(gymDetailProvider(gymId));
      ref.invalidate(gymListProvider);
      triggerPushSync(ref);
    }
  }

  Future<void> _deleteGym(BuildContext context, WidgetRef ref, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Gym'),
        content: Text('Delete "$name" and all its data?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(gymRepositoryProvider);
      await repo.delete(gymId);
      try { await Supabase.instance.client.from('gyms').delete().eq('id', gymId); } catch (_) {}
      ref.invalidate(gymListProvider);
      if (context.mounted) context.go('/gyms');
    }
  }

}
/// Filters projects to those at this gym that are completed.
final _gymCompletedProjectsProvider =
    FutureProvider.family<List<Project>, int>((ref, gymId) async {
  final projects = await ref.watch(projectListProvider.future);
  return projects.where((p) => p.gymId == gymId && p.status == 'completed').toList();
});

class _CompletedProjectsSection extends ConsumerWidget {
  const _CompletedProjectsSection({required this.gymId});

  final int gymId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedAsync = ref.watch(_gymCompletedProjectsProvider(gymId));

    return completedAsync.when(
      data: (projects) {
        if (projects.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Completed Projects'),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: projects
                    .map((p) => _ProjectCard(
                          project: p,
                          onTap: () => context
                              .push('/session-log/projects/${p.id}'),
                        ))
                    .toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Filters projects to those at this gym with status 'active'.
final _gymProjectsProvider =
    FutureProvider.family<List<Project>, int>((ref, gymId) async {
  final projects = await ref.watch(projectListProvider.future);
  return projects.where((p) => p.gymId == gymId && p.status == 'active').toList();
});

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project, required this.onTap});

  final Project project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(projectProgressProvider(project.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rocket_launch, size: 20, color: Colors.deepOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${project.gradeSystem} ${project.gradeValue}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              progressAsync.when(
                data: (progress) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.sendRate,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
                loading: () => const SizedBox(height: 6),
                error: (_, __) => const SizedBox(height: 6),
              ),
              const SizedBox(height: 4),
              progressAsync.when(
                data: (progress) => Text(
                  '${progress.sentClimbs} / ${progress.totalClimbs} sends',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── Rich metadata helpers ─────────────────────────────────────────────────

/// Whether the gym has any rich metadata worth showing.
bool _hasRichMetadata(Gym gym) {
  return gym.isDirectory ||
      gym.address != null ||
      gym.rating != null ||
      gym.phone != null ||
      gym.website != null ||
      gym.hours != null ||
      gym.dayPassPrice != null ||
      gym.description != null ||
      gym.hasBouldering == true ||
      gym.hasTopRope == true ||
      gym.hasLead == true ||
      gym.hasAutoBelay == true ||
      gym.hasTrainingArea == true ||
      gym.hasYoga == true ||
      gym.hasProShop == true ||
      gym.hasCafe == true ||
      gym.hasShowers == true ||
      gym.hasParking == true;
}

Future<void> _openMaps(String address) async {
  final encoded = Uri.encodeComponent(address);
  final uri = Uri.parse('https://maps.google.com/?q=$encoded');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _addToMyGyms(BuildContext context, WidgetRef ref, Gym gym) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;
  final db = ref.read(databaseProvider);

  // Prevent duplicate — check if user already has this gym
  final existing = await db.customSelect(
    'SELECT id FROM gyms WHERE name = ? AND user_id = ? LIMIT 1',
    variables: [
      Variable.withString(gym.name),
      Variable.withString(userId),
    ],
  ).getSingleOrNull();
  if (existing != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This gym is already in My Gyms')),
      );
    }
    return;
  }

  await db.gymsDao.updateUserId(gym.id, userId);
  ref.invalidate(myGymsProvider);
  ref.invalidate(directoryGymsProvider);
  ref.invalidate(gymListProvider);
  ref.invalidate(gymDetailProvider(gym.id));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${gym.name}" added to My Gyms')),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color ?? Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            if (onTap != null)
              const Icon(Icons.open_in_new, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _AmenitiesSection extends StatelessWidget {
  const _AmenitiesSection({required this.gym});
  final Gym gym;
  @override
  Widget build(BuildContext context) {
    final items = <_Amenity>[
      _Amenity('Bouldering', Icons.terrain, gym.hasBouldering == true),
      _Amenity('Top Rope', Icons.height, gym.hasTopRope == true),
      _Amenity('Lead', Icons.trending_up, gym.hasLead == true),
      _Amenity('Auto Belay', Icons.sync_alt, gym.hasAutoBelay == true),
      _Amenity('Training Area', Icons.fitness_center, gym.hasTrainingArea == true),
      _Amenity('Yoga', Icons.self_improvement, gym.hasYoga == true),
      _Amenity('Pro Shop', Icons.shopping_bag, gym.hasProShop == true),
      _Amenity('Cafe', Icons.local_cafe, gym.hasCafe == true),
      _Amenity('Showers', Icons.shower, gym.hasShowers == true),
      _Amenity('Parking', Icons.local_parking, gym.hasParking == true),
    ].where((a) => a.present).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: items
            .map((a) => Chip(
                  avatar: Icon(a.icon, size: 18),
                  label: Text(a.label),
                  visualDensity: VisualDensity.compact,
                ))
            .toList(),
      ),
    );
  }
}

class _Amenity {
  final String label;
  final IconData icon;
  final bool present;
  const _Amenity(this.label, this.icon, this.present);
}
