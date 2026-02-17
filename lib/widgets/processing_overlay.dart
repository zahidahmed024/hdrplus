import 'package:flutter/material.dart';

/// Semi-transparent processing overlay with progress steps.
class ProcessingOverlay extends StatelessWidget {
  final String currentStep;
  final double progress;
  final bool isVisible;

  const ProcessingOverlay({
    super.key,
    required this.currentStep,
    required this.progress,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated HDR icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: value > 0 ? value : null,
                        color: const Color(0xFFFFC107),
                        strokeWidth: 3,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const Icon(
                      Icons.hdr_on_rounded,
                      color: Color(0xFFFFC107),
                      size: 36,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Step label
            Text(
              currentStep,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            // Progress percentage
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                color: Color(0xFFFFC107),
                fontSize: 24,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
