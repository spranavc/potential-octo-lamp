import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../../data/providers/repository_providers.dart';
import '../providers/gym_providers.dart';

class GymColorsScreen extends ConsumerWidget {
  const GymColorsScreen({super.key, required this.gymId});

  final int gymId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymAsync = ref.watch(gymDetailProvider(gymId));
    final colorsAsync = ref.watch(gymColorsProvider(gymId));

    return gymAsync.when(
      data: (gym) => Scaffold(
        appBar: AppBar(title: Text('${gym?.name ?? 'Gym'} — Colors')),
        body: colorsAsync.when(
          data: (colors) {
            if (colors.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.palette_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No color mappings yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('Tap + to add a color-to-grade mapping',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: colors.length,
              itemBuilder: (context, index) {
                final c = colors[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _parseHex(c.colorHex),
                      child: const SizedBox.shrink(),
                    ),
                    title: Text(c.colorName),
                    subtitle: Text('${c.gradeValue} (${c.gradeSystem})'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editColor(context, ref, c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteColor(ref, c),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addColor(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add Color'),
        ),
      ),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Colors')),
        body: Center(child: Text('Error: $err')),
      ),
    );
  }

  Future<void> _addColor(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_ColorEntry>(
      context: context,
      builder: (ctx) => const _AddColorDialog(),
    );
    if (result != null) {
      final repo = ref.read(gymRepositoryProvider);
      await repo.addColor(
        gymId: gymId,
        colorName: result.colorName,
        colorHex: result.colorHex,
        gradeSystem: result.gradeSystem,
        gradeValue: result.gradeValue,
      );
      ref.invalidate(gymColorsProvider(gymId));
    }
  }

  Future<void> _editColor(BuildContext context, WidgetRef ref, GymColor existing) async {
    final result = await showDialog<_ColorEntry>(
      context: context,
      builder: (ctx) => _AddColorDialog(
        initialName: existing.colorName,
        initialHex: existing.colorHex,
        initialSystem: existing.gradeSystem,
        initialValue: existing.gradeValue,
      ),
    );
    if (result != null) {
      final repo = ref.read(gymRepositoryProvider);
      await repo.updateColor(
        existing.id,
        colorName: result.colorName,
        colorHex: result.colorHex,
        gradeSystem: result.gradeSystem,
        gradeValue: result.gradeValue,
      );
      ref.invalidate(gymColorsProvider(gymId));
    }
  }

  Future<void> _deleteColor(WidgetRef ref, GymColor color) async {
    final repo = ref.read(gymRepositoryProvider);
    await repo.deleteColor(color.id);
    ref.invalidate(gymColorsProvider(gymId));
  }
}

Color _parseHex(String hex) {
  final value = hex.replaceFirst('#', '');
  if (value.length == 6) {
    return Color(int.parse('FF$value', radix: 16));
  }
  return Colors.grey;
}

/// Preset color hex values for common hold colors.
const _presetColors = <String, String>{
  'Red': '#FF0000',
  'Orange': '#FF9800',
  'Yellow': '#FFEB3B',
  'Green': '#4CAF50',
  'Blue': '#2196F3',
  'Purple': '#9C27B0',
  'Pink': '#E91E63',
  'White': '#FFFFFF',
  'Black': '#000000',
  'Grey': '#9E9E9E',
  'Brown': '#795548',
  'Teal': '#009688',
};

class _ColorEntry {
  final String colorName;
  final String colorHex;
  final String gradeSystem;
  final String gradeValue;

  const _ColorEntry({
    required this.colorName,
    required this.colorHex,
    required this.gradeSystem,
    required this.gradeValue,
  });
}

class _AddColorDialog extends StatefulWidget {
  const _AddColorDialog({
    this.initialName,
    this.initialHex,
    this.initialSystem,
    this.initialValue,
  });

  final String? initialName;
  final String? initialHex;
  final String? initialSystem;
  final String? initialValue;

  bool get isEditing => initialName != null;

  @override
  State<_AddColorDialog> createState() => _AddColorDialogState();
}

class _AddColorDialogState extends State<_AddColorDialog> {
  final _nameController = TextEditingController();
  final _hexController = TextEditingController();
  final _gradeController = TextEditingController();
  late String _gradeSystem;
  String _colorNameFromPreset = '';

  @override
  void initState() {
    super.initState();
    _gradeSystem = widget.initialSystem ?? 'V-scale';
    _nameController.text = widget.initialName ?? '';
    _hexController.text = widget.initialHex ?? '#';
    _gradeController.text = widget.initialValue ?? '';
    if (widget.initialName != null) {
      _colorNameFromPreset = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hexController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit Color Mapping' : 'Add Color Mapping'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color presets
            const Text('Preset colors:', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _presetColors.entries.map((e) {
                final selected = _colorNameFromPreset == e.key;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _colorNameFromPreset = e.key;
                      _nameController.text = e.key;
                      _hexController.text = e.value;
                    });
                  },
                  child: Tooltip(
                    message: e.key,
                    child: CircleAvatar(
                      backgroundColor: _parseHex(e.value),
                      radius: selected ? 18 : 14,
                      child: selected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Color name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Color name',
                hintText: 'e.g. "Red", "Blue tape"',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Color hex
            TextField(
              controller: _hexController,
              decoration: const InputDecoration(
                labelText: 'Color hex',
                hintText: '#FF0000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Grade system dropdown
            DropdownButtonFormField<String>(
              initialValue: _gradeSystem,
              decoration: const InputDecoration(
                labelText: 'Grade system',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'V-scale', child: Text('V-scale')),
                DropdownMenuItem(value: 'Font', child: Text('Font')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _gradeSystem = v);
                }
              },
            ),
            const SizedBox(height: 12),

            // Grade value
            TextField(
              controller: _gradeController,
              decoration: InputDecoration(
                labelText: 'Grade value',
                hintText: _gradeSystem == 'V-scale' ? 'e.g. "V4"' : 'e.g. "6B+"',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final hex = _hexController.text.trim();
            final grade = _gradeController.text.trim();
            if (name.isEmpty || hex.isEmpty || grade.isEmpty) return;
            Navigator.pop(
              context,
              _ColorEntry(
                colorName: name,
                colorHex: hex,
                gradeSystem: _gradeSystem,
                gradeValue: grade,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
