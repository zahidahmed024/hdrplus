import 'package:flutter/material.dart';
import '../models/effect_preset.dart';
import 'control_slider.dart';

/// Bottom sheet panel for adjusting image processing effects.
class EffectsPanel extends StatelessWidget {
  final EffectPreset preset;
  final ValueChanged<EffectPreset> onChanged;

  const EffectsPanel({
    super.key,
    required this.preset,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF01A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Effects',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Reset all parameters to 0
                    final reset = preset.clone();
                    for (final param in reset.parameters) {
                      param.value = 0;
                    }
                    onChanged(reset);
                  },
                  child: const Text(
                    'RESET',
                    style: TextStyle(
                      color: Color(0xFFFFC107),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Effect sliders
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: preset.parameters.length,
              itemBuilder: (context, index) {
                final param = preset.parameters[index];
                return ControlSlider(
                  label: param.label,
                  value: param.value,
                  min: param.min,
                  max: param.max,
                  divisions: 40,
                  valueLabel: _formatValue(param),
                  activeColor: _colorForParam(param.name),
                  onChanged: (value) {
                    final updated = preset.clone();
                    updated.parameters[index].value = value;
                    onChanged(updated);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(EffectParameter param) {
    final val = param.value;
    if (val == 0) return '0';
    if (val > 0) return '+${(val * 100).round()}';
    return '${(val * 100).round()}';
  }

  Color _colorForParam(String name) {
    switch (name) {
      case 'contrast':
        return const Color(0xFF42A5F5);
      case 'vibrance':
        return const Color(0xFFAB47BC);
      case 'clarity':
        return const Color(0xFF66BB6A);
      case 'shadows':
        return const Color(0xFF78909C);
      case 'highlights':
        return const Color(0xFFFFEE58);
      case 'sharpen':
        return const Color(0xFFEF5350);
      case 'denoise':
        return const Color(0xFF26C6DA);
      case 'saturation':
        return const Color(0xFFFF7043);
      case 'temperature':
        return const Color(0xFFFFA726);
      default:
        return const Color(0xFFFFC107);
    }
  }
}
