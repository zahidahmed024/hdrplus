import 'package:flutter/material.dart';

/// Stylized HDR on/off toggle with animated glow effect.
class HdrToggle extends StatelessWidget {
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const HdrToggle({
    super.key,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isEnabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isEnabled
                  ? const Color(0xFFFFC107).withOpacity(0.2)
                  : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isEnabled ? const Color(0xFFFFC107) : Colors.white24,
            width: 1.5,
          ),
          boxShadow:
              isEnabled
                  ? [
                    BoxShadow(
                      color: const Color(0xFFFFC107).withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hdr_on_rounded,
              size: 20,
              color: isEnabled ? const Color(0xFFFFC107) : Colors.white38,
            ),
            const SizedBox(width: 6),
            Text(
              'HDR',
              style: TextStyle(
                color: isEnabled ? const Color(0xFFFFC107) : Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
