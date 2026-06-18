import 'package:flutter/material.dart';

/// A bottom sheet that lets the user pick a grade system and grade value.
class GradePicker extends StatefulWidget {
  const GradePicker({
    super.key,
    required this.onSelected,
    this.initialSystem,
    this.initialValue,
  });

  final void Function(String system, String value) onSelected;
  final String? initialSystem;
  final String? initialValue;

  static void show(
    BuildContext context, {
    required void Function(String system, String value) onSelected,
    String? initialSystem,
    String? initialValue,
  }) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => GradePicker(
        onSelected: onSelected,
        initialSystem: initialSystem,
        initialValue: initialValue,
      ),
    );
  }

  @override
  State<GradePicker> createState() => _GradePickerState();
}

class _GradePickerState extends State<GradePicker> {
  late String _system;
  late String _value;

  static const _vGrades = ['V0', 'V1', 'V2', 'V3', 'V4', 'V5', 'V6', 'V7', 'V8', 'V9', 'V10', 'V11', 'V12', 'V13', 'V14', 'V15', 'V16', 'V17'];
  static const _fontGrades = ['3', '4', '5', '5+', '6A', '6A+', '6B', '6B+', '6C', '6C+', '7A', '7A+', '7B', '7B+', '7C', '7C+', '8A', '8A+', '8B', '8B+', '8C', '8C+', '9A'];

  @override
  void initState() {
    super.initState();
    _system = widget.initialSystem ?? 'V-scale';
    _value = widget.initialValue ?? 'V0';
  }

  @override
  Widget build(BuildContext context) {
    final grades = _system == 'V-scale' ? _vGrades : _fontGrades;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // System toggle
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'V-scale', label: Text('V-scale')),
              ButtonSegment(value: 'Font', label: Text('Font')),
            ],
            selected: {_system},
            onSelectionChanged: (selected) {
              setState(() {
                _system = selected.first;
                _value = _system == 'V-scale' ? 'V0' : '6A';
              });
            },
          ),
          const SizedBox(height: 16),

          // Grade grid
          SizedBox(
            height: 220,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.5,
              ),
              itemCount: grades.length,
              itemBuilder: (context, index) {
                final grade = grades[index];
                final isSelected = grade == _value;
                return FilledButton.tonal(
                  onPressed: () {
                    setState(() => _value = grade);
                    widget.onSelected(_system, grade);
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(grade, style: const TextStyle(fontWeight: FontWeight.w600)),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
