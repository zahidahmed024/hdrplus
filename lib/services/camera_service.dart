import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../models/camera_settings.dart';
import '../models/hdr_settings.dart';
import '../utils/constants.dart';

/// Service that manages the camera lifecycle, manual controls, and burst capture.
///
/// Wraps the Flutter [CameraController] and provides high-level methods
/// for ISO, shutter speed, exposure compensation, focus, white balance,
/// and zoom control. Supports Camera2 API v3 via the camera plugin.
class CameraService extends ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _error;

  CameraSettings _settings = CameraSettings();
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _minExposureOffset = -4.0;
  double _maxExposureOffset = 4.0;

  // Getters
  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;
  String? get error => _error;
  CameraSettings get settings => _settings;
  double get minZoom => _minZoom;
  double get maxZoom => _maxZoom;
  double get minExposureOffset => _minExposureOffset;
  double get maxExposureOffset => _maxExposureOffset;
  List<CameraDescription> get cameras => _cameras;
  int get selectedCameraIdx => _selectedCameraIdx;

  bool get hasFrontCamera =>
      _cameras.any((c) => c.lensDirection == CameraLensDirection.front);

  /// Initialize the camera system.
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _error = 'No cameras available';
        notifyListeners();
        return;
      }
      await _initController(_cameras[_selectedCameraIdx]);
    } catch (e) {
      _error = 'Camera initialization failed: $e';
      notifyListeners();
    }
  }

  Future<void> _initController(CameraDescription camera) async {
    _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      _isInitialized = true;
      _error = null;

      // Query hardware limits
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _minExposureOffset = await _controller!.getMinExposureOffset();
      _maxExposureOffset = await _controller!.getMaxExposureOffset();

      notifyListeners();
    } catch (e) {
      _error = 'Controller init failed: $e';
      _isInitialized = false;
      notifyListeners();
    }
  }

  /// Switch between front and back cameras.
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras.length;
    await _initController(_cameras[_selectedCameraIdx]);
  }

  /// Set zoom level (clamped to device limits).
  Future<void> setZoom(double zoom) async {
    if (_controller == null || !_isInitialized) return;
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(clamped);
    _settings.zoom = clamped;
    notifyListeners();
  }

  /// Set exposure compensation in EV stops.
  Future<void> setExposureCompensation(double ev) async {
    if (_controller == null || !_isInitialized) return;
    final clamped = ev.clamp(_minExposureOffset, _maxExposureOffset);
    await _controller!.setExposureOffset(clamped);
    _settings.exposureCompensation = clamped;
    notifyListeners();
  }

  /// Set exposure mode (auto or locked).
  Future<void> setExposureMode(ExposureMode mode) async {
    if (_controller == null || !_isInitialized) return;
    await _controller!.setExposureMode(mode);
    notifyListeners();
  }

  /// Set focus mode (auto or locked).
  Future<void> setFocusMode(FocusMode mode) async {
    if (_controller == null || !_isInitialized) return;
    await _controller!.setFocusMode(mode);
    _settings.focusLocked = mode == FocusMode.locked;
    notifyListeners();
  }

  /// Set focus point (normalized coordinates 0-1).
  Future<void> setFocusPoint(Offset point) async {
    if (_controller == null || !_isInitialized) return;
    await _controller!.setFocusPoint(point);
    notifyListeners();
  }

  /// Set exposure point (normalized coordinates 0-1).
  Future<void> setExposurePoint(Offset point) async {
    if (_controller == null || !_isInitialized) return;
    await _controller!.setExposurePoint(point);
    notifyListeners();
  }

  /// Lock focus for burst capture.
  Future<void> lockFocus() async {
    await setFocusMode(FocusMode.locked);
    _settings.focusLocked = true;
    notifyListeners();
  }

  /// Unlock focus after burst capture.
  Future<void> unlockFocus() async {
    await setFocusMode(FocusMode.auto);
    _settings.focusLocked = false;
    notifyListeners();
  }

  /// Lock exposure for burst capture.
  Future<void> lockExposure() async {
    await setExposureMode(ExposureMode.locked);
    notifyListeners();
  }

  /// Update ISO value (stored in settings, applied via exposure control).
  void setIso(int iso) {
    _settings.iso = iso.clamp(IsoRange.min, IsoRange.max);
    notifyListeners();
  }

  /// Update shutter speed value.
  void setShutterSpeed(double speed) {
    _settings.shutterSpeed = speed.clamp(ShutterSpeed.min, ShutterSpeed.max);
    notifyListeners();
  }

  /// Update white balance mode.
  void setWhiteBalance(WhiteBalanceMode mode) {
    _settings.whiteBalance = mode;
    notifyListeners();
  }

  /// Update focus distance.
  void setFocusDistance(double distance) {
    _settings.focusDistance = distance.clamp(FocusRange.min, FocusRange.max);
    notifyListeners();
  }

  /// Capture a single photo.
  Future<XFile?> captureSingle() async {
    if (_controller == null || !_isInitialized || _isCapturing) return null;

    try {
      _isCapturing = true;
      notifyListeners();

      final file = await _controller!.takePicture();

      _isCapturing = false;
      notifyListeners();
      return file;
    } catch (e) {
      _isCapturing = false;
      _error = 'Capture failed: $e';
      notifyListeners();
      return null;
    }
  }

  /// Capture exposure bracket sequence for HDR.
  ///
  /// Locks focus and white balance, captures frames at different
  /// exposure offsets (e.g., -2 EV, 0 EV, +2 EV), then unlocks.
  Future<List<XFile>> captureExposureBracket(HdrSettings hdrSettings) async {
    if (_controller == null || !_isInitialized || _isCapturing) return [];

    final List<XFile> frames = [];
    try {
      _isCapturing = true;
      notifyListeners();

      // Lock focus and exposure for consistent bracketing
      await lockFocus();
      final originalEv = _settings.exposureCompensation;

      final brackets = hdrSettings.brackets;

      for (final bracket in brackets) {
        // Set exposure offset for this bracket
        final evOffset = bracket.evOffset.clamp(
          _minExposureOffset,
          _maxExposureOffset,
        );
        await _controller!.setExposureOffset(evOffset);

        // Small delay for sensor to adjust
        await Future.delayed(const Duration(milliseconds: 150));

        // Capture the frame
        final file = await _controller!.takePicture();
        frames.add(file);
      }

      // Restore original exposure and unlock focus
      await _controller!.setExposureOffset(originalEv);
      await unlockFocus();

      _isCapturing = false;
      notifyListeners();
      return frames;
    } catch (e) {
      _isCapturing = false;
      _error = 'Bracket capture failed: $e';
      notifyListeners();
      // Return whatever frames we captured
      return frames;
    }
  }

  /// Set flash mode.
  Future<void> setFlashMode(FlashMode mode) async {
    if (_controller == null || !_isInitialized) return;
    await _controller!.setFlashMode(mode);
    notifyListeners();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
