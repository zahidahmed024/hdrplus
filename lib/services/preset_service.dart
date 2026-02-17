import 'package:shared_preferences/shared_preferences.dart';
import '../models/effect_preset.dart';

/// Manages saving, loading, and deleting effect presets.
///
/// Built-in presets are always available. Custom presets are
/// persisted to SharedPreferences as JSON.
class PresetService {
  static const String _storageKey = 'hdrplus_custom_presets';

  /// Returns all available presets (built-in + custom).
  Future<List<EffectPreset>> getAllPresets() async {
    final builtIn = EffectPreset.builtInPresets();
    final custom = await getCustomPresets();
    return [...builtIn, ...custom];
  }

  /// Returns only custom (user-created) presets.
  Future<List<EffectPreset>> getCustomPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];
    return jsonList.map((json) => EffectPreset.fromJsonString(json)).toList();
  }

  /// Save a new custom preset.
  Future<void> savePreset(EffectPreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];

    // Remove existing preset with same ID (update)
    jsonList.removeWhere((json) {
      final existing = EffectPreset.fromJsonString(json);
      return existing.id == preset.id;
    });

    jsonList.add(preset.toJsonString());
    await prefs.setStringList(_storageKey, jsonList);
  }

  /// Delete a custom preset by ID.
  Future<void> deletePreset(String presetId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];

    jsonList.removeWhere((json) {
      final preset = EffectPreset.fromJsonString(json);
      return preset.id == presetId;
    });

    await prefs.setStringList(_storageKey, jsonList);
  }

  /// Check if a preset is a built-in preset.
  bool isBuiltIn(String presetId) {
    return EffectPreset.builtInPresets().any((p) => p.id == presetId);
  }
}
