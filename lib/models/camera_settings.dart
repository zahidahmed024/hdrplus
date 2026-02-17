import '../utils/constants.dart';

/// White balance mode presets.
enum WhiteBalanceMode {
  auto('Auto', 0),
  daylight('Daylight', 5500),
  cloudy('Cloudy', 6500),
  tungsten('Tungsten', 2700),
  fluorescent('Fluorescent', 4000),
  shade('Shade', 7500);

  const WhiteBalanceMode(this.label, this.temperature);
  final String label;
  final int temperature;
}

/// Holds the current camera control values.
class CameraSettings {
  int iso;
  double shutterSpeed;
  double exposureCompensation;
  double focusDistance;
  WhiteBalanceMode whiteBalance;
  double zoom;
  bool focusLocked;
  bool wbLocked;

  CameraSettings({
    this.iso = IsoRange.defaultValue,
    this.shutterSpeed = ShutterSpeed.defaultValue,
    this.exposureCompensation = ExposureRange.defaultValue,
    this.focusDistance = FocusRange.defaultValue,
    this.whiteBalance = WhiteBalanceMode.auto,
    this.zoom = ZoomRange.defaultValue,
    this.focusLocked = false,
    this.wbLocked = false,
  });

  CameraSettings copyWith({
    int? iso,
    double? shutterSpeed,
    double? exposureCompensation,
    double? focusDistance,
    WhiteBalanceMode? whiteBalance,
    double? zoom,
    bool? focusLocked,
    bool? wbLocked,
  }) {
    return CameraSettings(
      iso: iso ?? this.iso,
      shutterSpeed: shutterSpeed ?? this.shutterSpeed,
      exposureCompensation: exposureCompensation ?? this.exposureCompensation,
      focusDistance: focusDistance ?? this.focusDistance,
      whiteBalance: whiteBalance ?? this.whiteBalance,
      zoom: zoom ?? this.zoom,
      focusLocked: focusLocked ?? this.focusLocked,
      wbLocked: wbLocked ?? this.wbLocked,
    );
  }

  Map<String, dynamic> toJson() => {
    'iso': iso,
    'shutterSpeed': shutterSpeed,
    'exposureCompensation': exposureCompensation,
    'focusDistance': focusDistance,
    'whiteBalance': whiteBalance.name,
    'zoom': zoom,
  };

  factory CameraSettings.fromJson(Map<String, dynamic> json) {
    return CameraSettings(
      iso: json['iso'] as int? ?? IsoRange.defaultValue,
      shutterSpeed:
          (json['shutterSpeed'] as num?)?.toDouble() ??
          ShutterSpeed.defaultValue,
      exposureCompensation:
          (json['exposureCompensation'] as num?)?.toDouble() ??
          ExposureRange.defaultValue,
      focusDistance:
          (json['focusDistance'] as num?)?.toDouble() ??
          FocusRange.defaultValue,
      whiteBalance: WhiteBalanceMode.values.firstWhere(
        (e) => e.name == json['whiteBalance'],
        orElse: () => WhiteBalanceMode.auto,
      ),
      zoom: (json['zoom'] as num?)?.toDouble() ?? ZoomRange.defaultValue,
    );
  }
}
