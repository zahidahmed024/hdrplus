import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Vertical zoom control with slider + quick-tap 1x/2x/4x/10x markers.
/// Sliding UP = zoom IN.
class ZoomSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const ZoomSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  /// Quick-tap zoom levels
  static const List<double> _presets = [1.0, 2.0, 4.0, 10.0];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 280,
      child: Column(
        children: [
          // Current zoom badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${value.toStringAsFixed(1)}x',
              style: const TextStyle(
                color: Color(0xFFFFC107),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Vertical slider
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: const Color(0xFFFFC107).withOpacity(0.6),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFFFFC107),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
                  ),
                  trackHeight: 2.5,
                  overlayColor: const Color(0xFFFFC107).withOpacity(0.15),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    onChanged(v);
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Quick-tap zoom presets
          ..._presets
              .where((z) => z >= min && z <= max)
              .map(
                (zoom) => _ZoomPresetButton(
                  label: '${zoom.toInt()}x',
                  isActive: (value - zoom).abs() < 0.05,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onChanged(zoom);
                  },
                ),
              ),
        ],
      ),
    );
  }
}

class _ZoomPresetButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ZoomPresetButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 28,
          decoration: BoxDecoration(
            color:
                isActive
                    ? const Color(0xFFFFC107).withOpacity(0.2)
                    : Colors.black38,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  isActive
                      ? const Color(0xFFFFC107).withOpacity(0.6)
                      : Colors.white12,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? const Color(0xFFFFC107) : Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
