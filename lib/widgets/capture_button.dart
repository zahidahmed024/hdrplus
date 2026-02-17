import 'package:flutter/material.dart';

/// Animated capture button with pulsing ring during capture.
/// Shows different states: ready, capturing, processing.
class CaptureButton extends StatefulWidget {
  final bool isCapturing;
  final bool isProcessing;
  final bool hdrEnabled;
  final VoidCallback onPressed;

  const CaptureButton({
    super.key,
    this.isCapturing = false,
    this.isProcessing = false,
    this.hdrEnabled = false,
    required this.onPressed,
  });

  @override
  State<CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<CaptureButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(CaptureButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCapturing && !oldWidget.isCapturing) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isCapturing && oldWidget.isCapturing) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.isCapturing || widget.isProcessing;

    return GestureDetector(
      onTap: isDisabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isCapturing ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      widget.hdrEnabled
                          ? const Color(0xFFFFC107)
                          : Colors.white,
                  width: 4,
                ),
                boxShadow:
                    widget.hdrEnabled
                        ? [
                          BoxShadow(
                            color: const Color(0xFFFFC107).withOpacity(0.3),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                        : null,
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      widget.isProcessing
                          ? Colors.white24
                          : widget.isCapturing
                          ? Colors.red
                          : Colors.white,
                ),
                child:
                    widget.isProcessing
                        ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                        : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
