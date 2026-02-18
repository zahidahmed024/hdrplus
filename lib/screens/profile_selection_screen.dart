import 'package:flutter/material.dart';

import '../models/effect_preset.dart';
import '../services/preset_service.dart';
import 'camera_screen.dart';

/// Profile selection screen — the app's home screen.
/// Users select an effect profile before starting capture.
class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  final PresetService _presetService = PresetService();
  List<EffectPreset> _profiles = [];
  String? _selectedId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await _presetService.getAllPresets();
    final lastId = await _presetService.getLastSelectedProfileId();
    if (mounted) {
      setState(() {
        _profiles = profiles;
        // select last used, or first available
        if (lastId != null && profiles.any((p) => p.id == lastId)) {
          _selectedId = lastId;
        } else if (profiles.isNotEmpty) {
          _selectedId = profiles.first.id;
        }
        _isLoading = false;
      });
    }
  }

  void _selectProfile(String id) {
    setState(() => _selectedId = id);
  }

  Future<void> _startCapture() async {
    if (_selectedId == null) return;

    await _presetService.setLastSelectedProfileId(_selectedId!);
    final selected = _profiles.firstWhere((p) => p.id == _selectedId);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(selectedProfile: selected),
      ),
    );
  }

  Future<void> _deleteProfile(EffectPreset profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text(
              'Delete Profile',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Delete "${profile.name}"?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Color(0xFFEF5350)),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _presetService.deletePreset(profile.id);
      await _loadProfiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HDR+',
                    style: TextStyle(
                      color: const Color(0xFFFFC107),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a profile to start capturing',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Profiles grid
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFFC107),
                        ),
                      )
                      : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.3,
                            ),
                        itemCount: _profiles.length,
                        itemBuilder: (context, index) {
                          final profile = _profiles[index];
                          return _buildProfileCard(profile);
                        },
                      ),
            ),

            // Start Capture button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedId != null ? _startCapture : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white24,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_rounded, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Start Capture',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(EffectPreset profile) {
    final isSelected = profile.id == _selectedId;
    final isCustom = !profile.isBuiltIn;

    return GestureDetector(
      onTap: () => _selectProfile(profile.id),
      onLongPress: isCustom ? () => _deleteProfile(profile) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFFFFC107).withOpacity(0.12)
                  : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected
                    ? const Color(0xFFFFC107)
                    : Colors.white.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: const Color(0xFFFFC107).withOpacity(0.12),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                  : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _iconForProfile(profile.id),
                    color:
                        isSelected ? const Color(0xFFFFC107) : Colors.white54,
                    size: 24,
                  ),
                  const Spacer(),
                  if (isSelected)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFC107),
                      ),
                    ),
                  if (isCustom && !isSelected)
                    Icon(Icons.person, size: 14, color: Colors.white24),
                ],
              ),
              const Spacer(),
              Text(
                profile.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _parameterSummary(profile),
                style: TextStyle(color: Colors.white30, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _parameterSummary(EffectPreset profile) {
    final active = profile.parameters.where((p) => p.value != 0).toList();
    if (active.isEmpty) return 'No adjustments';
    return active
        .take(3)
        .map(
          (p) =>
              '${p.label} ${p.value > 0 ? '+' : ''}${(p.value * 100).round()}',
        )
        .join(' · ');
  }

  IconData _iconForProfile(String id) {
    switch (id) {
      case 'natural':
        return Icons.nature;
      case 'vivid':
        return Icons.color_lens;
      case 'cinematic':
        return Icons.movie_filter;
      case 'bw':
        return Icons.monochrome_photos;
      case 'hdr_dramatic':
        return Icons.hdr_strong;
      default:
        return Icons.tune;
    }
  }
}
