import 'package:flutter/material.dart';
import '../models/hdr_settings.dart';
import '../models/export_settings.dart';

/// Settings screen for app-wide configuration.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  HdrSettings _hdrSettings = const HdrSettings();
  ExportSettings _exportSettings = const ExportSettings();

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
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // HDR Settings Section
          _buildSectionHeader('HDR Settings'),
          _buildCard([
            _buildDropdownTile<HdrMergeMethod>(
              'Merge Method',
              Icons.merge_type,
              _hdrSettings.mergeMethod,
              HdrMergeMethod.values,
              (v) => setState(
                () => _hdrSettings = _hdrSettings.copyWith(mergeMethod: v),
              ),
            ),
            _buildDivider(),
            _buildDropdownTile<ToneMappingCurve>(
              'Tone Mapping',
              Icons.tonality,
              _hdrSettings.toneMappingCurve,
              ToneMappingCurve.values,
              (v) => setState(
                () => _hdrSettings = _hdrSettings.copyWith(toneMappingCurve: v),
              ),
            ),
            _buildDivider(),
            _buildSliderTile(
              'EV Spacing',
              Icons.exposure,
              _hdrSettings.evSpacing,
              1.0,
              3.0,
              (v) => setState(
                () => _hdrSettings = _hdrSettings.copyWith(evSpacing: v),
              ),
              valueLabel: '±${_hdrSettings.evSpacing.toStringAsFixed(1)} EV',
            ),
            _buildDivider(),
            _buildSwitchTile(
              'Auto Align',
              Icons.straighten,
              _hdrSettings.autoAlign,
              (v) => setState(
                () => _hdrSettings = _hdrSettings.copyWith(autoAlign: v),
              ),
            ),
            _buildDivider(),
            _buildSliderTile(
              'Gamma',
              Icons.brightness_6,
              _hdrSettings.toneMappingGamma,
              0.5,
              3.0,
              (v) => setState(
                () => _hdrSettings = _hdrSettings.copyWith(toneMappingGamma: v),
              ),
              valueLabel: _hdrSettings.toneMappingGamma.toStringAsFixed(1),
            ),
          ]),

          const SizedBox(height: 24),

          // Export Settings Section
          _buildSectionHeader('Export Settings'),
          _buildCard([
            _buildDropdownTile<ExportFormat>(
              'Default Format',
              Icons.image,
              _exportSettings.format,
              ExportFormat.values,
              (v) => setState(
                () => _exportSettings = _exportSettings.copyWith(format: v),
              ),
            ),
            _buildDivider(),
            _buildSliderTile(
              'JPEG Quality',
              Icons.high_quality,
              _exportSettings.jpegQuality.toDouble(),
              50,
              100,
              (v) => setState(
                () =>
                    _exportSettings = _exportSettings.copyWith(
                      jpegQuality: v.round(),
                    ),
              ),
              valueLabel: '${_exportSettings.jpegQuality}%',
            ),
            _buildDivider(),
            _buildSwitchTile(
              'Preserve Metadata',
              Icons.info_outline,
              _exportSettings.preserveMetadata,
              (v) => setState(
                () =>
                    _exportSettings = _exportSettings.copyWith(
                      preserveMetadata: v,
                    ),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About'),
          _buildCard([
            ListTile(
              leading: const Icon(
                Icons.camera_enhance,
                color: Color(0xFFFFC107),
              ),
              title: const Text(
                'HDR+ Camera',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'v1.0.0',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFFFC107),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 56,
      color: Colors.white.withOpacity(0.06),
    );
  }

  Widget _buildSwitchTile(
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white54, size: 22),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFFFC107),
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    IconData icon,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String? valueLabel,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white54, size: 22),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: SliderTheme(
        data: SliderThemeData(
          activeTrackColor: const Color(0xFFFFC107).withOpacity(0.7),
          inactiveTrackColor: Colors.white12,
          thumbColor: const Color(0xFFFFC107),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          trackHeight: 2,
        ),
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ),
      trailing: Text(
        valueLabel ?? value.toStringAsFixed(1),
        style: const TextStyle(
          color: Color(0xFFFFC107),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildDropdownTile<T extends Enum>(
    String title,
    IconData icon,
    T value,
    List<T> items,
    ValueChanged<T> onChanged,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white54, size: 22),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      trailing: DropdownButton<T>(
        value: value,
        dropdownColor: const Color(0xFF1A1A2E),
        underline: const SizedBox.shrink(),
        style: const TextStyle(color: Color(0xFFFFC107), fontSize: 13),
        items:
            items.map((item) {
              final label =
                  item is HdrMergeMethod
                      ? item.label
                      : item is ToneMappingCurve
                      ? item.label
                      : item is ExportFormat
                      ? item.label
                      : item.name;
              return DropdownMenuItem<T>(value: item, child: Text(label));
            }).toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}
