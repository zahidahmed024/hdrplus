import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../models/effect_preset.dart';
import '../models/export_settings.dart';
import '../services/effects_engine.dart';
import '../services/export_service.dart';
import '../services/preset_service.dart';
import '../utils/image_utils.dart';
import '../widgets/before_after_view.dart';
import '../widgets/effects_panel.dart';
import '../widgets/preset_card.dart';

/// Post-capture editing screen with effects, presets, and before/after comparison.
class EditScreen extends StatefulWidget {
  final img.Image image;
  final Uint8List originalImageBytes;
  final EffectPreset? initialPreset;

  const EditScreen({
    super.key,
    required this.image,
    required this.originalImageBytes,
    this.initialPreset,
  });

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final EffectsEngine _effectsEngine = EffectsEngine();
  final ExportService _exportService = ExportService();
  final PresetService _presetService = PresetService();

  late Uint8List _displayBytes;
  late EffectPreset _currentPreset;
  List<EffectPreset> _presets = [];
  bool _showBeforeAfter = false;
  bool _isProcessing = false;
  bool _isExporting = false;
  ExportSettings _exportSettings = const ExportSettings();

  // Debounce timer for slider changes
  Timer? _debounceTimer;
  // Version counter to discard stale results
  int _processVersion = 0;

  @override
  void initState() {
    super.initState();
    _displayBytes = imageToJpegBytes(widget.image, quality: 85);
    _currentPreset = widget.initialPreset?.clone() ?? EffectPreset.natural();
    _loadPresets();

    // Apply initial preset if provided
    if (widget.initialPreset != null) {
      Future.microtask(() => _applyPreset(_currentPreset));
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    final presets = await _presetService.getAllPresets();
    if (mounted) setState(() => _presets = presets);
  }

  Future<void> _applyPreset(EffectPreset preset) async {
    _processVersion++;
    final thisVersion = _processVersion;

    setState(() {
      _currentPreset = preset.clone();
      _isProcessing = true;
    });

    try {
      // Use preview-resolution processing for fast feedback
      final result = await _effectsEngine.applyPresetPreview(
        widget.image,
        preset,
      );
      // Discard if a newer request was made
      if (thisVersion != _processVersion || !mounted) return;
      setState(() {
        _displayBytes = imageToJpegBytes(result, quality: 80);
        _isProcessing = false;
      });
    } catch (e) {
      if (thisVersion == _processVersion && mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Debounced handler for slider changes — waits 300ms after last
  /// change before starting expensive processing.
  Future<void> _onPresetChanged(EffectPreset preset) async {
    // Update UI immediately (slider position)
    setState(() => _currentPreset = preset.clone());

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyPreset(preset);
    });
  }

  Future<void> _exportImage() async {
    setState(() => _isExporting = true);

    // Process at FULL resolution for export
    final fullRes = await _effectsEngine.applyPreset(
      widget.image,
      _currentPreset,
    );

    final path = await _exportService.exportImage(fullRes, _exportSettings);

    setState(() => _isExporting = false);

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
                  'Saved to gallery',
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
    }
  }

  Future<void> _saveCustomPreset() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text(
              'Save Preset',
              style: TextStyle(color: Colors.white),
            ),
            content: TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Preset name',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFFFC107)),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, nameController.text),
                child: const Text(
                  'Save',
                  style: TextStyle(color: Color(0xFFFFC107)),
                ),
              ),
            ],
          ),
    );

    if (name != null && name.isNotEmpty) {
      final preset = _currentPreset.clone();
      preset.name = name;
      final customPreset = EffectPreset(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        parameters: preset.parameters,
      );
      await _presetService.savePreset(customPreset);
      await _loadPresets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preset "$name" saved'),
            backgroundColor: const Color(0xFF2D2D3A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Before/After toggle
          IconButton(
            icon: Icon(
              Icons.compare,
              color:
                  _showBeforeAfter ? const Color(0xFFFFC107) : Colors.white54,
              size: 22,
            ),
            onPressed: () {
              setState(() => _showBeforeAfter = !_showBeforeAfter);
            },
          ),

          // Save preset
          IconButton(
            icon: const Icon(
              Icons.bookmark_add,
              color: Colors.white54,
              size: 22,
            ),
            onPressed: _saveCustomPreset,
          ),

          // Export
          _isExporting
              ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFC107),
                    strokeWidth: 2,
                  ),
                ),
              )
              : PopupMenuButton<ExportFormat>(
                icon: const Icon(
                  Icons.save_alt,
                  color: Color(0xFFFFC107),
                  size: 22,
                ),
                color: const Color(0xFF1A1A2E),
                onSelected: (format) {
                  _exportSettings = _exportSettings.copyWith(format: format);
                  _exportImage();
                },
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: ExportFormat.jpeg,
                        child: Text(
                          'Save as JPEG (High Quality)',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const PopupMenuItem(
                        value: ExportFormat.png16bit,
                        child: Text(
                          'Save as PNG (16-bit)',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
              ),
        ],
      ),
      body: Column(
        children: [
          // Image preview
          Expanded(
            flex: 5,
            child:
                _showBeforeAfter
                    ? BeforeAfterView(
                      beforeImage: widget.originalImageBytes,
                      afterImage: _displayBytes,
                    )
                    : Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Image.memory(
                            _displayBytes,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                        if (_isProcessing)
                          Container(
                            color: Colors.black45,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFFFC107),
                              ),
                            ),
                          ),
                      ],
                    ),
          ),

          // Presets carousel
          PresetCard(
            presets: _presets,
            selectedId: _currentPreset.id,
            onSelected: _applyPreset,
          ),

          // Save as Profile button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: _saveCustomPreset,
                icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                label: const Text(
                  'Save as Profile',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFC107),
                  side: BorderSide(
                    color: const Color(0xFFFFC107).withOpacity(0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          // Effects panel
          Expanded(
            flex: 4,
            child: EffectsPanel(
              preset: _currentPreset,
              onChanged: _onPresetChanged,
            ),
          ),
        ],
      ),
    );
  }
}
