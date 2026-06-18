import 'package:flutter/material.dart';

/// A card that responds to horizontal swipe or tap to indicate send (right) or
/// fail (left).
///
/// The card displays grade info, tags, attempts, and RPE. Swiping right logs
/// a send; swiping left logs a fail. Tapping the send/fail buttons does the
/// same. The card has a subtle colored overlay that follows the drag.
class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.gradeSystem,
    required this.gradeValue,
    required this.selectedTagIds,
    required this.attempts,
    required this.rpe,
    required this.tagLabels,
    required this.onSend,
    required this.onFail,
    this.onEditGrade,
    this.projectName,
  });

  final String gradeSystem;
  final String gradeValue;
  final List<int> selectedTagIds;
  final int attempts;
  final double? rpe;
  final String tagLabels;
  final VoidCallback onSend;
  final VoidCallback onFail;
  final VoidCallback? onEditGrade;
  final String? projectName;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  double _dragOffset = 0;
  static const _swipeThreshold = 80.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset = (_dragOffset + details.delta.dx).clamp(-200, 200);
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset > _swipeThreshold) {
          _animateAndCall(widget.onSend);
        } else if (_dragOffset < -_swipeThreshold) {
          _animateAndCall(widget.onFail);
        } else {
          setState(() => _dragOffset = 0);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
          // ignore: deprecated_member_use
          ..translate(_dragOffset)
          ..rotateZ(_dragOffset * 0.001),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Grade display (tap to change)
                InkWell(
                  onTap: widget.onEditGrade,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          widget.gradeValue,
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.gradeSystem,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Project indicator
                if (widget.projectName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rocket_launch, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          widget.projectName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Tags
                if (widget.tagLabels.isNotEmpty)
                  Text(
                    widget.tagLabels,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  )
                else
                  const Text('No tags', style: TextStyle(color: Colors.grey)),

                const SizedBox(height: 16),

                // Attempts
                Text(
                  'Attempt #${widget.attempts}',
                  style: theme.textTheme.bodySmall,
                ),

                // RPE
                if (widget.rpe != null)
                  Text(
                    'RPE: ${widget.rpe!.round()}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),

                const SizedBox(height: 16),

                // Send / Fail buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      label: 'FAIL',
                      icon: Icons.close,
                      color: Colors.red,
                      onTap: widget.onFail,
                    ),
                    _ActionButton(
                      label: 'SEND',
                      icon: Icons.check,
                      color: Colors.green,
                      onTap: widget.onSend,
                    ),
                  ],
                ),

                // Swipe hint
                const SizedBox(height: 12),
                Text(
                  '← Swipe left to fail · Swipe right to send →',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _animateAndCall(VoidCallback callback) {
    setState(() => _dragOffset = 0);
    callback();
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color.withAlpha(30),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
