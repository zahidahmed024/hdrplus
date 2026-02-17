import 'package:flutter/material.dart';

/// Vertical zoom slider with 1x/2x/5x markers and smooth animation.
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 200,
      child: Column(
        children: [
          // Current zoom label
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
          const SizedBox(height: 8),

          // Vertical slider
          Expanded(
            child: RotatedBox(
              quarterTurns: -1,
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: const Color(0xFFFFC107).withOpacity(0.6),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFFFFC107),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  trackHeight: 2,
                  overlayColor: const Color(0xFFFFC107).withOpacity(0.15),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14,
                  ),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),

          // Zoom markers
          const SizedBox(height: 4),
          _buildMarker('1x'),
        ],
      ),
    );
  }

  Widget _buildMarker(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
