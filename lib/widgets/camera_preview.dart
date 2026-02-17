import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';

/// Full-screen camera preview with tap-to-focus and focus ring animation.
class CameraPreviewWidget extends StatefulWidget {
  final CameraService cameraService;
  final VoidCallback? onTapDown;

  const CameraPreviewWidget({
    super.key,
    required this.cameraService,
    this.onTapDown,
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget>
    with SingleTickerProviderStateMixin {
  Offset? _focusPoint;
  late AnimationController _focusAnimController;
  late Animation<double> _focusAnimation;

  @override
  void initState() {
    super.initState();
    _focusAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _focusAnimation = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(parent: _focusAnimController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _focusAnimController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details, BoxConstraints constraints) {
    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;

    widget.cameraService.setFocusPoint(Offset(x, y));
    widget.cameraService.setExposurePoint(Offset(x, y));

    setState(() {
      _focusPoint = details.localPosition;
    });

    _focusAnimController.reset();
    _focusAnimController.forward();

    // Hide focus ring after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _focusPoint = null);
    });

    widget.onTapDown?.call();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.cameraService.controller;
    if (controller == null || !widget.cameraService.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) => _handleTapDown(details, constraints),
          onScaleUpdate: (details) {
            if (details.scale != 1.0) {
              final currentZoom = widget.cameraService.settings.zoom;
              final newZoom = (currentZoom * details.scale).clamp(
                widget.cameraService.minZoom,
                widget.cameraService.maxZoom,
              );
              widget.cameraService.setZoom(newZoom);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview
              ClipRect(
                child: OverflowBox(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height:
                          constraints.maxWidth * controller.value.aspectRatio,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
              ),

              // Focus ring indicator
              if (_focusPoint != null)
                AnimatedBuilder(
                  animation: _focusAnimation,
                  builder: (context, child) {
                    return Positioned(
                      left: _focusPoint!.dx - 30,
                      top: _focusPoint!.dy - 30,
                      child: Transform.scale(
                        scale: _focusAnimation.value,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFFFC107),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
