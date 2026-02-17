import 'package:flutter/material.dart';
import '../models/effect_preset.dart';

/// Horizontal scrollable preset selection cards.
class PresetCard extends StatelessWidget {
  final List<EffectPreset> presets;
  final String? selectedId;
  final ValueChanged<EffectPreset> onSelected;

  const PresetCard({
    super.key,
    required this.presets,
    this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: presets.length,
        itemBuilder: (context, index) {
          final preset = presets[index];
          final isSelected = preset.id == selectedId;

          return GestureDetector(
            onTap: () => onSelected(preset),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? const Color(0xFFFFC107).withOpacity(0.15)
                        : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFFFFC107) : Colors.white12,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: const Color(0xFFFFC107).withOpacity(0.15),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                        : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _iconForPreset(preset.id),
                    size: 22,
                    color:
                        isSelected ? const Color(0xFFFFC107) : Colors.white54,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preset.name,
                    style: TextStyle(
                      color:
                          isSelected ? const Color(0xFFFFC107) : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _iconForPreset(String id) {
    switch (id) {
      case 'natural':
        return Icons.nature;
      case 'vivid':
        return Icons.color_lens;
      case 'cinematic':
        return Icons.movie_filter;
      case 'bw':
        return Icons.monochrome_photos;
      case 'hdr_dramatic':
        return Icons.hdr_strong;
      default:
        return Icons.tune;
    }
  }
}
