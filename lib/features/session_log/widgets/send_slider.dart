import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A vertical completion slider that replaces the old SEND/FAIL swipe card.
///
/// Displays the grade value prominently (tappable to edit), a large completion
/// percentage that tracks vertical drag (up = more complete, down = less),
/// and side-by-side "Log Worked" / "Log Sent" buttons.
///
/// Starts at 0% completion. The bar fills bottom-to-top with a color gradient.
/// At 95%: resistance kicks in (delta * 0.2). At 100%: the bar pulses,
/// haptic feedback fires, and [onLogSent] is called after a brief delay.
class SendSlider extends StatefulWidget {
  const SendSlider({
    super.key,
    required this.gradeValue,
    this.onEditGrade,
    required this.onLogWorked,
  });

  final String gradeValue;
  final VoidCallback? onEditGrade;
  final void Function(int completionPercent) onLogWorked;

  @override
  State<SendSlider> createState() => _SendSliderState();
}

class _SendSliderState extends State<SendSlider>
    with SingleTickerProviderStateMixin {
  // ── Completion state ──────────────────────────────────────────────────────
  double _percent = 0.0;
  bool _hasTriggeredSent = false;

  // ── Pulse animation ───────────────────────────────────────────────────────
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _pulseController.forward();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _updatePercent(double delta) {
    if (_hasTriggeredSent) return;

    double effectiveDelta = delta;

    // Resistance at 95%+
    if (_percent >= 95.0 && delta > 0) {
      effectiveDelta = delta * 0.2;
    }

    setState(() {
      _percent = (_percent + effectiveDelta).clamp(0.0, 100.0);
    });

    // Haptic + pulse at 95%
    if (_percent >= 95.0) {
      HapticFeedback.heavyImpact();
    }

    // Pulse + trigger sent at 100%
    if (_percent >= 100.0 && !_hasTriggeredSent) {
      _hasTriggeredSent = true;
      _pulseController.repeat(reverse: true);
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          widget.onLogWorked(100);
        }
      });
    }
  }

  Future<void> _showPercentDialog() async {
    final controller = TextEditingController(text: _percent.round().toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Completion %'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Enter percentage (0-100)',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            final parsed = int.tryParse(v);
            if (parsed != null) {
              Navigator.pop(ctx, parsed.clamp(0, 100));
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text);
              Navigator.pop(ctx, parsed?.clamp(0, 100));
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _percent = result.toDouble();
        if (_percent >= 100.0 && !_hasTriggeredSent) {
          _hasTriggeredSent = true;
          _pulseController.repeat(reverse: true);
          Future<void>.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              widget.onLogWorked(100);
            }
          });
        }
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAt100 = _percent >= 100.0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Grade display (tappable to edit) ──────────────────────────
            InkWell(
              onTap: widget.onEditGrade,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  widget.gradeValue,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Completion % (tappable to type) ───────────────────────────
            GestureDetector(
              onTap: _showPercentDialog,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: isAt100 ? _pulseAnimation.value : 1.0,
                    child: child,
                  );
                },
                child: Text(
                  '${_percent.round()}%',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),
            Text(
              'Tap to change difficulty',
              style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
            ),

            const SizedBox(height: 16),

            // ── Vertical drag bar ─────────────────────────────────────────
            SizedBox(
              height: 200,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  // Drag up (negative delta) → increase percent
                  // Drag down (positive delta) → decrease percent
                  // Map pixel drag to a reasonable percent change
                  final deltaPercent = -details.delta.dy * 0.5;
                  _updatePercent(deltaPercent);
                },
                child: Container(
                  width: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // Background
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      // Filled portion (bottom to top)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 50),
                          curve: Curves.easeOut,
                          height: 200 * (_percent / 100.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            gradient: null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      // Center hint text
                      Center(
                        child: Text(
                          'SWIPE UP',
                          style: TextStyle(
                            color: _percent > 50
                                ? Colors.white.withAlpha(180)
                                : Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (isAt100)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Sent!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // ── Slider instructions ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Swipe up all the way when you complete a problem, '
                'or slide up to how much you were able to complete.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),

            // ── Action button ─────────────────────────────────────────────
            Center(
              child: FilledButton.icon(
                onPressed:
                    _hasTriggeredSent ? null : () => widget.onLogWorked(_percent.round()),
                icon: const Icon(Icons.fitness_center),
                label: const Text('Log Climb'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
