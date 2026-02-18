import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable pro-mode slider with label, value display, and +/- step buttons.
/// Supports haptic feedback and dark camera-style theming.
class ControlSlider extends StatelessWidget {
  final String label;
  final String? valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final Color? activeColor;
  final IconData? icon;

  const ControlSlider({
    super.key,
    required this.label,
    this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.activeColor,
    this.icon,
  });

  /// Step size for +/- buttons (matches slider divisions)
  double get _step {
    if (divisions != null && divisions! > 0) {
      return (max - min) / divisions!;
    }
    return (max - min) / 40; // default 40 divisions
  }

  void _increment() {
    final next = (value + _step).clamp(min, max);
    if (next != value) {
      HapticFeedback.selectionClick();
      onChanged(next);
    }
  }

  void _decrement() {
    final next = (value - _step).clamp(min, max);
    if (next != value) {
      HapticFeedback.selectionClick();
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? const Color(0xFFFFC107);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          // Icon or label
          SizedBox(
            width: 50,
            child:
                icon != null
                    ? Icon(icon, color: Colors.white70, size: 20)
                    : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
          ),

          // Minus button
          _StepButton(
            icon: Icons.remove,
            color: color,
            onTap: value > min ? _decrement : null,
          ),

          // Slider
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color.withOpacity(0.8),
                inactiveTrackColor: Colors.white12,
                thumbColor: color,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                trackHeight: 2,
                overlayColor: color.withOpacity(0.2),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  onChanged(v);
                },
              ),
            ),
          ),

          // Plus button
          _StepButton(
            icon: Icons.add,
            color: color,
            onTap: value < max ? _increment : null,
          ),

          // Value display
          SizedBox(
            width: 48,
            child: Text(
              valueLabel ?? value.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact circular step button for fine-tuning slider values.
class _StepButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              isEnabled
                  ? color.withOpacity(0.12)
                  : Colors.white.withOpacity(0.04),
          border: Border.all(
            color:
                isEnabled
                    ? color.withOpacity(0.3)
                    : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Icon(icon, size: 14, color: isEnabled ? color : Colors.white24),
      ),
    );
  }
}
