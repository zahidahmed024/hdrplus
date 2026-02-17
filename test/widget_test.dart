import 'package:flutter_test/flutter_test.dart';
import 'package:hdrplus/models/effect_preset.dart';
import 'package:hdrplus/models/camera_settings.dart';
import 'package:hdrplus/models/export_settings.dart';

void main() {
  group('EffectPreset', () {
    test('default parameters have correct count', () {
      final params = EffectPreset.defaultParameters();
      expect(params.length, 9);
    });

    test('built-in presets are created correctly', () {
      final presets = EffectPreset.builtInPresets();
      expect(presets.length, 5);
      expect(presets.first.name, 'Natural');
      expect(presets.last.name, 'HDR Dramatic');
    });

    test('serialization roundtrip preserves data', () {
      final original = EffectPreset.vivid();
      final json = original.toJsonString();
      final restored = EffectPreset.fromJsonString(json);
      expect(restored.name, original.name);
      expect(restored.id, original.id);
      expect(restored.parameters.length, original.parameters.length);
      for (int i = 0; i < original.parameters.length; i++) {
        expect(restored.parameters[i].value, original.parameters[i].value);
      }
    });

    test('clone creates independent copy', () {
      final original = EffectPreset.cinematic();
      final clone = original.clone();
      clone.parameters[0].value = 0.99;
      expect(original.parameters[0].value != 0.99, true);
    });
  });

  group('CameraSettings', () {
    test('default values are correct', () {
      final settings = CameraSettings();
      expect(settings.iso, 100);
      expect(settings.focusLocked, false);
    });

    test('JSON roundtrip works', () {
      final settings = CameraSettings(iso: 800, zoom: 2.5);
      final json = settings.toJson();
      final restored = CameraSettings.fromJson(json);
      expect(restored.iso, 800);
      expect(restored.zoom, 2.5);
    });
  });

  group('ExportSettings', () {
    test('defaults are correct', () {
      const settings = ExportSettings();
      expect(settings.format, ExportFormat.jpeg);
      expect(settings.jpegQuality, 95);
      expect(settings.preserveMetadata, true);
    });
  });
}
