import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable pro-mode slider with label, value display, and custom range.
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

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? const Color(0xFFFFC107);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

          // Value display
          SizedBox(
            width: 60,
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
