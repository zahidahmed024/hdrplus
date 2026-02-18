import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../models/camera_settings.dart';
import '../models/effect_preset.dart';
import '../models/hdr_settings.dart';

import '../services/camera_service.dart';
import '../services/hdr_processor.dart';
import '../utils/image_utils.dart';
import '../utils/constants.dart';
import '../widgets/camera_preview.dart';
import '../widgets/control_slider.dart';
import '../widgets/hdr_toggle.dart';
import '../widgets/capture_button.dart';
import '../widgets/processing_overlay.dart';
import '../widgets/zoom_slider.dart';
import 'capture_review_screen.dart';
import 'edit_screen.dart';
import 'gallery_screen.dart';
import 'settings_screen.dart';

/// Main camera screen with live preview, pro controls, and HDR capture.
class CameraScreen extends StatefulWidget {
  final EffectPreset? selectedProfile;

  const CameraScreen({super.key, this.selectedProfile});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  late CameraService _cameraService;
  final HdrProcessor _hdrProcessor = HdrProcessor();

  HdrSettings _hdrSettings = const HdrSettings(enabled: false);
  bool _showProControls = false;
  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String _processingStep = '';
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraService = CameraService();
    _initCamera();
  }

  Future<void> _initCamera() async {
    await _cameraService.initialize();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cameraService.controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    super.dispose();
  }

  /// Handle capture: single shot or HDR bracket.
  Future<void> _handleCapture() async {
    if (_cameraService.isCapturing || _isProcessing) return;

    if (_hdrSettings.enabled) {
      await _captureHdr();
    } else {
      await _captureSingle();
    }
  }

  Future<void> _captureSingle() async {
    final file = await _cameraService.captureSingle();
    if (file == null || !mounted) return;

    final bytes = await File(file.path).readAsBytes();
    // Decode in background isolate to keep UI responsive
    final image = await Isolate.run(() => img.decodeImage(bytes));
    if (image == null || !mounted) return;

    _navigateToEdit(image, bytes);
  }

  Future<void> _captureHdr() async {
    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _processingStep = 'Capturing brackets...';
    });

    // 1. Capture exposure bracket
    final files = await _cameraService.captureExposureBracket(_hdrSettings);
    if (files.isEmpty || !mounted) {
      setState(() => _isProcessing = false);
      return;
    }

    // 2. Decode frames
    setState(() {
      _processingProgress = 0.15;
      _processingStep = 'Decoding frames...';
    });

    final List<img.Image> frames = [];
    for (final file in files) {
      final bytes = await File(file.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) frames.add(decoded);
    }

    if (frames.isEmpty || !mounted) {
      setState(() => _isProcessing = false);
      return;
    }

    // Save original for before/after
    final originalBytes = imageToJpegBytes(frames[frames.length ~/ 2]);

    // 3. HDR merge
    final hdrResult = await _hdrProcessor.process(
      frames,
      _hdrSettings,
      onProgress: (progress, step) {
        if (mounted) {
          setState(() {
            _processingProgress = 0.15 + progress * 0.7;
            _processingStep = step;
          });
        }
      },
    );

    setState(() {
      _processingProgress = 0.9;
      _processingStep = 'Finalizing...';
    });

    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _processingProgress = 1.0;
    });

    _navigateToEdit(hdrResult, originalBytes);
  }

  void _navigateToEdit(img.Image image, Uint8List originalBytes) {
    if (widget.selectedProfile != null) {
      // Profile selected → go to review screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => CaptureReviewScreen(
                image: image,
                originalImageBytes: originalBytes,
                selectedProfile: widget.selectedProfile!,
              ),
        ),
      );
    } else {
      // No profile → go straight to editor
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) =>
                  EditScreen(image: image, originalImageBytes: originalBytes),
        ),
      );
    }
  }

  void _toggleFlash() {
    setState(() {
      switch (_flashMode) {
        case FlashMode.off:
          _flashMode = FlashMode.auto;
          break;
        case FlashMode.auto:
          _flashMode = FlashMode.always;
          break;
        case FlashMode.always:
          _flashMode = FlashMode.torch;
          break;
        case FlashMode.torch:
          _flashMode = FlashMode.off;
          break;
      }
    });
    _cameraService.setFlashMode(_flashMode);
  }

  IconData _flashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.flashlight_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            Positioned.fill(
              child: CameraPreviewWidget(cameraService: _cameraService),
            ),

            // Top bar (HDR toggle, flash, settings)
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),

            // Profile badge
            if (widget.selectedProfile != null)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withOpacity(0.15),
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
                          widget.selectedProfile!.name,
                          style: const TextStyle(
                            color: Color(0xFFFFC107),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Zoom slider (right edge)
            Positioned(
              right: 8,
              top: MediaQuery.of(context).size.height * 0.25,
              child: ZoomSlider(
                value: _cameraService.settings.zoom,
                min: _cameraService.minZoom,
                max: _cameraService.maxZoom.clamp(1.0, 10.0),
                onChanged: (v) {
                  _cameraService.setZoom(v);
                  setState(() {});
                },
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),

            // Pro controls drawer
            if (_showProControls)
              Positioned(
                bottom: 130,
                left: 0,
                right: 0,
                child: _buildProControls(),
              ),

            // Processing overlay
            Positioned.fill(
              child: ProcessingOverlay(
                isVisible: _isProcessing,
                currentStep: _processingStep,
                progress: _processingProgress,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.6), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Flash control
          IconButton(
            icon: Icon(_flashIcon(), color: Colors.white, size: 24),
            onPressed: _toggleFlash,
          ),

          // HDR toggle
          HdrToggle(
            isEnabled: _hdrSettings.enabled,
            onChanged: (enabled) {
              setState(() {
                _hdrSettings = _hdrSettings.copyWith(enabled: enabled);
              });
            },
          ),

          // Settings
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.only(bottom: 24, top: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pro controls toggle
          GestureDetector(
            onTap: () => setState(() => _showProControls = !_showProControls),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color:
                    _showProControls
                        ? const Color(0xFFFFC107).withOpacity(0.15)
                        : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      _showProControls
                          ? const Color(0xFFFFC107).withOpacity(0.5)
                          : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune,
                    size: 16,
                    color:
                        _showProControls
                            ? const Color(0xFFFFC107)
                            : Colors.white54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'PRO',
                    style: TextStyle(
                      color:
                          _showProControls
                              ? const Color(0xFFFFC107)
                              : Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Main controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery button
              IconButton(
                icon: const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.white70,
                  size: 28,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GalleryScreen()),
                  );
                },
              ),

              // Capture button
              CaptureButton(
                isCapturing: _cameraService.isCapturing,
                isProcessing: _isProcessing,
                hdrEnabled: _hdrSettings.enabled,
                onPressed: _handleCapture,
              ),

              // Switch camera
              IconButton(
                icon: const Icon(
                  Icons.flip_camera_ios_rounded,
                  color: Colors.white70,
                  size: 28,
                ),
                onPressed: () async {
                  await _cameraService.switchCamera();
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProControls() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ISO
          ControlSlider(
            label: 'ISO',
            value: _cameraService.settings.iso.toDouble(),
            min: IsoRange.min.toDouble(),
            max: IsoRange.max.toDouble(),
            divisions: 20,
            valueLabel: '${_cameraService.settings.iso}',
            icon: Icons.iso,
            onChanged: (v) {
              _cameraService.setIso(v.round());
              setState(() {});
            },
          ),

          // Exposure Compensation
          ControlSlider(
            label: 'EV',
            value: _cameraService.settings.exposureCompensation,
            min: _cameraService.minExposureOffset,
            max: _cameraService.maxExposureOffset,
            divisions: 24,
            valueLabel:
                '${_cameraService.settings.exposureCompensation > 0 ? '+' : ''}${_cameraService.settings.exposureCompensation.toStringAsFixed(1)}',
            icon: Icons.exposure,
            activeColor: const Color(0xFF42A5F5),
            onChanged: (v) {
              _cameraService.setExposureCompensation(v);
              setState(() {});
            },
          ),

          // Shutter Speed
          ControlSlider(
            label: 'SS',
            value: _cameraService.settings.shutterSpeed * 1000,
            min: ShutterSpeed.min * 1000,
            max: ShutterSpeed.max * 1000,
            divisions: 20,
            valueLabel: ShutterSpeed.label(
              _cameraService.settings.shutterSpeed,
            ),
            icon: Icons.shutter_speed,
            activeColor: const Color(0xFF66BB6A),
            onChanged: (v) {
              _cameraService.setShutterSpeed(v / 1000);
              setState(() {});
            },
          ),

          // Focus Distance
          ControlSlider(
            label: 'FOCUS',
            value: _cameraService.settings.focusDistance,
            min: FocusRange.min,
            max: FocusRange.max,
            divisions: 20,
            valueLabel:
                _cameraService.settings.focusDistance < 0.1
                    ? '∞'
                    : '${(_cameraService.settings.focusDistance * 100).round()}%',
            icon: Icons.center_focus_strong,
            activeColor: const Color(0xFFAB47BC),
            onChanged: (v) {
              _cameraService.setFocusDistance(v);
              setState(() {});
            },
          ),

          // White Balance selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const SizedBox(
                  width: 50,
                  child: Icon(Icons.wb_sunny, color: Colors.white70, size: 20),
                ),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children:
                          WhiteBalanceMode.values.map((mode) {
                            final isSelected =
                                _cameraService.settings.whiteBalance == mode;
                            return GestureDetector(
                              onTap: () {
                                _cameraService.setWhiteBalance(mode);
                                setState(() {});
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? const Color(
                                            0xFFFFA726,
                                          ).withOpacity(0.2)
                                          : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? const Color(0xFFFFA726)
                                            : Colors.white12,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    mode.label,
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? const Color(0xFFFFA726)
                                              : Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
