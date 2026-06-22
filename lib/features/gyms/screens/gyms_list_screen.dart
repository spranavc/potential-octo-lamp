import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../data/database/database.dart';
import '../../../data/providers/database_provider.dart';
import '../../../data/providers/repository_providers.dart';
import '../../sync/providers/sync_providers.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_card.dart';

/// Which tab is selected on the gyms list screen.
enum _GymTab { myGyms, directory }

/// Tracks the currently selected tab on the gyms list screen.
final _selectedTabProvider = StateProvider<_GymTab>((ref) => _GymTab.myGyms);

/// Computes the set of directory gym names that the user has already added
/// (by checking [myGymsProvider]).  The directory tab uses this to decide
/// whether to show an "Add" or "Added" button on each card.
final _addedDirectoryGymNamesProvider = Provider<Set<String>>((ref) {
  final myGyms = ref.watch(myGymsProvider).valueOrNull;
  if (myGyms == null) return const {};
  return myGyms.map((g) => g.name.toLowerCase()).toSet();
});

class GymsListScreen extends ConsumerWidget {
  const GymsListScreen({super.key});

  // ── Add a new (blank) user gym ─────────────────────────────────────────────

  Future<void> _addGym(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _AddGymDialog(),
    );
    if (name != null && name.trim().isNotEmpty) {
      final repo = ref.read(gymRepositoryProvider);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await repo.create(name.trim(), userId: userId);
      ref.invalidate(myGymsProvider);
      triggerPushSync(ref);
    }
  }

  // ── Copy a directory gym into the user's gyms ──────────────────────────────

  Future<void> _addDirectoryGym(WidgetRef ref, Gym gym) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final db = ref.read(databaseProvider);
    await db.into(db.gyms).insert(
      GymsCompanion.insert(
        name: gym.name,
        userId: Value(userId),
        latitude: Value(gym.latitude),
        longitude: Value(gym.longitude),
        address: Value(gym.address),
        phone: Value(gym.phone),
        website: Value(gym.website),
        description: Value(gym.description),
        photoUrl: Value(gym.photoUrl),
        rating: Value(gym.rating),
        ratingCount: Value(gym.ratingCount),
        hours: Value(gym.hours),
        dayPassPrice: Value(gym.dayPassPrice),
        hasBouldering: Value(gym.hasBouldering),
        hasTopRope: Value(gym.hasTopRope),
        hasLead: Value(gym.hasLead),
        hasAutoBelay: Value(gym.hasAutoBelay),
        hasTrainingArea: Value(gym.hasTrainingArea),
        hasYoga: Value(gym.hasYoga),
        hasProShop: Value(gym.hasProShop),
        hasCafe: Value(gym.hasCafe),
        hasShowers: Value(gym.hasShowers),
        hasParking: Value(gym.hasParking),
        isDirectory: const Value(false),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
        createdAt: Value(DateTime.now()),
      ),
    );
    ref.invalidate(myGymsProvider);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(_selectedTabProvider);
    final myGyms = ref.watch(myGymsProvider).valueOrNull;
    final hasMyGyms = myGyms != null && myGyms.isNotEmpty;

    // If the user has no gyms yet, force Directory tab
    if (!hasMyGyms && selectedTab == _GymTab.myGyms) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_selectedTabProvider.notifier).state = _GymTab.directory;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gyms'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<_GymTab>(
              segments: [
                ButtonSegment<_GymTab>(
                  value: _GymTab.myGyms,
                  label: Text('My Gyms'),
                  icon: Icon(Icons.fitness_center),
                  enabled: hasMyGyms,
                ),
                ButtonSegment<_GymTab>(
                  value: _GymTab.directory,
                  label: Text('Directory'),
                  icon: Icon(Icons.travel_explore),
                ),
              ],
              selected: {selectedTab},
              onSelectionChanged: (selection) {
                if (selection.first == _GymTab.myGyms && !hasMyGyms) return;
                ref.read(_selectedTabProvider.notifier).state = selection.first;
              },
            ),
          ),
        ),
      ),
      body: selectedTab == _GymTab.myGyms
          ? _MyGymsTab(onAddGym: () => _addGym(context, ref))
          : _DirectoryTab(onAddGym: (gym) => _addDirectoryGym(ref, gym)),
      bottomNavigationBar: selectedTab == _GymTab.directory
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  onPressed: () => _addGym(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Gym Not in Directory'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// My Gyms tab
// ═══════════════════════════════════════════════════════════════════════════════

class _MyGymsTab extends ConsumerWidget {
  const _MyGymsTab({required this.onAddGym});

  final VoidCallback onAddGym;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymsAsync = ref.watch(myGymsProvider);

    return gymsAsync.when(
      data: (gyms) {
        if (gyms.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fitness_center, size: 72, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome to Boldr!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add your gym or browse the Directory tab\nfor gyms in the DMV area.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onAddGym,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Your First Gym'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: gyms.length,
          itemBuilder: (context, index) {
            final gym = gyms[index];
            return Dismissible(
              key: ValueKey(gym.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Gym'),
                    content: Text(
                      'Delete "${gym.name}" and all its sessions, walls, and colors?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  final repo = ref.read(gymRepositoryProvider);
                  await repo.delete(gym.id);
                  // Also delete from Supabase
                  try { await Supabase.instance.client.from('gyms').delete().eq('id', gym.id); } catch (_) {}
                  ref.invalidate(myGymsProvider);
                }
                return false; // We handle deletion ourselves
              },
              child: GymCard(
                gym: gym,
                onTap: () => context.go('/gyms/${gym.id}'),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Directory tab
// ═══════════════════════════════════════════════════════════════════════════════

class _DirectoryTab extends ConsumerWidget {
  const _DirectoryTab({required this.onAddGym});

  final void Function(Gym gym) onAddGym;

  List<Widget> _buildAmenityChips(Gym gym) {
    final chips = <Widget>[];
    if (gym.hasBouldering == true) {
      chips.add(const _AmenityChip(label: 'Bouldering'));
    }
    if (gym.hasTopRope == true) {
      chips.add(const _AmenityChip(label: 'Top Rope'));
    }
    if (gym.hasLead == true) {
      chips.add(const _AmenityChip(label: 'Lead'));
    }
    if (gym.hasAutoBelay == true) {
      chips.add(const _AmenityChip(label: 'Auto Belay'));
    }
    if (gym.hasTrainingArea == true) {
      chips.add(const _AmenityChip(label: 'Training'));
    }
    if (gym.hasYoga == true) {
      chips.add(const _AmenityChip(label: 'Yoga'));
    }
    if (gym.hasCafe == true) {
      chips.add(const _AmenityChip(label: 'Cafe'));
    }
    if (gym.hasShowers == true) {
      chips.add(const _AmenityChip(label: 'Showers'));
    }
    return chips;
  }

  Widget _buildRatingStars(double? rating) {
    if (rating == null || rating <= 0) return const SizedBox.shrink();
    final fullStars = rating.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(fullStars, (_) => const Icon(Icons.star, size: 16, color: Colors.amber)),
        Text(
          ' ${rating.toStringAsFixed(1)}',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directoryGymsAsync = ref.watch(directoryGymsProvider);
    final addedNames = ref.watch(_addedDirectoryGymNamesProvider);

    return directoryGymsAsync.when(
      data: (gyms) {
        if (gyms.isEmpty) {
          return const Center(child: Text('No directory gyms available.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: gyms.length,
          itemBuilder: (context, index) {
            final gym = gyms[index];
            final alreadyAdded =
                addedNames.contains(gym.name.toLowerCase());

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/gyms/${gym.id}'),
                child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row with add/added button
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            gym.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (alreadyAdded)
                          const Chip(
                            avatar: Icon(Icons.check, size: 18, color: Colors.green),
                            label: Text('Added'),
                            backgroundColor: Color(0xFFE8F5E9),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: 'Add to my gyms',
                            onPressed: () => onAddGym(gym),
                          ),
                      ],
                    ),
                    // Address
                    if (gym.address != null && gym.address!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              gym.address!,
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Rating
                    _buildRatingStars(gym.rating),
                    // Amenity chips
                    if (_buildAmenityChips(gym).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _buildAmenityChips(gym),
                      ),
                    ],
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }
}

// ── Amenity chip ─────────────────────────────────────────────────────────────

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Add Gym dialog
// ═══════════════════════════════════════════════════════════════════════════════

class _AddGymDialog extends StatelessWidget {
  const _AddGymDialog();

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();

    return AlertDialog(
      title: const Text('Add Gym'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Gym name',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
