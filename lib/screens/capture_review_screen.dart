import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/effect_preset.dart';
import '../models/export_settings.dart';
import '../services/effects_engine.dart';
import '../services/export_service.dart';
import '../utils/image_utils.dart';
import 'edit_screen.dart';

/// Post-capture review screen.
///
/// Shows the captured image with the selected profile's effects applied.
/// Two options: Save (auto-export) or Edit (open editor).
class CaptureReviewScreen extends StatefulWidget {
  final img.Image image;
  final Uint8List originalImageBytes;
  final EffectPreset selectedProfile;

  const CaptureReviewScreen({
    super.key,
    required this.image,
    required this.originalImageBytes,
    required this.selectedProfile,
  });

  @override
  State<CaptureReviewScreen> createState() => _CaptureReviewScreenState();
}

class _CaptureReviewScreenState extends State<CaptureReviewScreen> {
  final EffectsEngine _effectsEngine = EffectsEngine();
  final ExportService _exportService = ExportService();

  late Uint8List _displayBytes;
  img.Image? _processedImage; // Cached processed result for saving
  bool _isProcessing = true;
  bool _isSaving = false;
  bool _previewReady = false;

  @override
  void initState() {
    super.initState();
    _displayBytes = imageToJpegBytes(widget.image, quality: 85);
    _applyProfile();
  }

  Future<void> _applyProfile() async {
    try {
      // Process at a good quality resolution (2048px max for save-worthy output)
      final result = await _effectsEngine.applyPresetPreview(
        widget.image,
        widget.selectedProfile,
        maxPreviewDim: 2048,
      );
      if (mounted) {
        setState(() {
          _processedImage = result;
          _displayBytes = imageToJpegBytes(result, quality: 80);
          _isProcessing = false;
          _previewReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _saveImage() async {
    if (!_previewReady || _processedImage == null) return;

    setState(() => _isSaving = true);

    // Save the already-processed image directly (no reprocessing needed)
    final path = await _exportService.exportImage(
      _processedImage!,
      const ExportSettings(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF66BB6A),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saved with "${widget.selectedProfile.name}" profile',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2D2D3A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Return to camera
      if (mounted) Navigator.pop(context);
    }
  }

  void _openEditor() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => EditScreen(
              image: widget.image,
              originalImageBytes: widget.originalImageBytes,
              initialPreset: widget.selectedProfile,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with profile name
            _buildTopBar(),

            // Image preview
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.memory(
                      _displayBytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                  if (_isProcessing)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFFFFC107),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Applying "${widget.selectedProfile.name}"...',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom action bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFC107).withOpacity(0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_fix_high,
                  size: 14,
                  color: Color(0xFFFFC107),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.selectedProfile.name,
                  style: const TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // balance the back button
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          // Edit button
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : _openEditor,
                icon: const Icon(Icons.edit_rounded, size: 20),
                label: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Save button
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_isProcessing || _isSaving) ? null : _saveImage,
                icon:
                    _isSaving
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                        : const Icon(Icons.save_alt_rounded, size: 20),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white12,
                  disabledForegroundColor: Colors.white24,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
