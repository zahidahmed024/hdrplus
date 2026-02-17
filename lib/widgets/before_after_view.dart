import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Before/after split-screen comparison widget with draggable divider.
class BeforeAfterView extends StatefulWidget {
  final Uint8List beforeImage;
  final Uint8List afterImage;

  const BeforeAfterView({
    super.key,
    required this.beforeImage,
    required this.afterImage,
  });

  @override
  State<BeforeAfterView> createState() => _BeforeAfterViewState();
}

class _BeforeAfterViewState extends State<BeforeAfterView> {
  double _dividerPosition = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final dividerX = width * _dividerPosition;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dividerPosition = (details.localPosition.dx / width).clamp(
                0.05,
                0.95,
              );
            });
          },
          child: Stack(
            children: [
              // After image (full width, underneath)
              Positioned.fill(
                child: Image.memory(
                  widget.afterImage,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),

              // Before image (clipped to left portion)
              ClipRect(
                clipper: _LeftClipper(dividerX),
                child: Image.memory(
                  widget.beforeImage,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  width: width,
                  height: height,
                ),
              ),

              // Divider line
              Positioned(
                left: dividerX - 1.5,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 3,
                  color: Colors.white,
                  child: const SizedBox.expand(),
                ),
              ),

              // Divider handle
              Positioned(
                left: dividerX - 18,
                top: height / 2 - 18,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.drag_handle,
                    color: Colors.black87,
                    size: 20,
                  ),
                ),
              ),

              // Labels
              Positioned(left: 12, top: 12, child: _buildLabel('BEFORE')),
              Positioned(right: 12, top: 12, child: _buildLabel('AFTER')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

/// Custom clipper that clips to the left portion of the widget.
class _LeftClipper extends CustomClipper<Rect> {
  final double width;
  _LeftClipper(this.width);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, size.height);

  @override
  bool shouldReclip(_LeftClipper oldClipper) => oldClipper.width != width;
}
