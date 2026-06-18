import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';

/// A horizontal scrollable row of selectable style tag chips.
class TagChips extends ConsumerWidget {
  const TagChips({
    super.key,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<int> selectedIds;
  final void Function(List<int> tagIds) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);

    return tagsAsync.when(
      data: (tags) => _TagChipRow(
        tags: tags,
        selectedIds: selectedIds,
        onChanged: onChanged,
      ),
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => const SizedBox(height: 40),
    );
  }
}

class _TagChipRow extends StatelessWidget {
  const _TagChipRow({
    required this.tags,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<Tag> tags;
  final List<int> selectedIds;
  final void Function(List<int> tagIds) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: tags.map((tag) {
        final isSelected = selectedIds.contains(tag.id);
        return FilterChip(
          label: Text(_tagLabel(tag.name)),
          selected: isSelected,
          onSelected: (selected) {
            final newIds = List<int>.from(selectedIds);
            if (selected) {
              newIds.add(tag.id);
            } else {
              newIds.remove(tag.id);
            }
            onChanged(newIds);
          },
          avatar: Icon(
            _tagIcon(tag.name),
            size: 18,
          ),
        );
      }).toList(),
    );
  }

  String _tagLabel(String name) {
    return name[0].toUpperCase() + name.substring(1);
  }

  IconData _tagIcon(String name) {
    switch (name) {
      case 'crimpy':
        return Icons.pinch;
      case 'dynamic':
        return Icons.bolt;
      case 'slopey':
        return Icons.waving_hand;
      case 'overhang':
        return Icons.roofing;
      case 'slab':
        return Icons.straighten;
      default:
        return Icons.label;
    }
  }
}

/// Provider for the list of all tags.
final tagsProvider = FutureProvider<List<Tag>>((ref) {
  return ref.watch(tagRepositoryProvider).getAll();
});
