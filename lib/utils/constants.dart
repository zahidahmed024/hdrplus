/// App-wide constants for the HDR+ camera application.
library;

/// ISO sensitivity range values
class IsoRange {
  static const int min = 50;
  static const int max = 3200;
  static const int defaultValue = 100;
  static const List<int> presets = [50, 100, 200, 400, 800, 1600, 3200];
}

/// Shutter speed values (in seconds, represented as fractions)
class ShutterSpeed {
  static const double min = 1 / 8000; // 1/8000s
  static const double max = 1.0; // 1s
  static const double defaultValue = 1 / 60; // 1/60s

  /// Common shutter speed presets as fractions of a second
  static const List<double> presets = [
    1 / 8000,
    1 / 4000,
    1 / 2000,
    1 / 1000,
    1 / 500,
    1 / 250,
    1 / 125,
    1 / 60,
    1 / 30,
    1 / 15,
    1 / 8,
    1 / 4,
    1 / 2,
    1.0,
  ];

  /// Returns human-readable label for a shutter speed value.
  static String label(double speed) {
    if (speed >= 1.0) return '${speed.toInt()}s';
    final denominator = (1 / speed).round();
    return '1/${denominator}s';
  }
}

/// Exposure compensation in EV stops
class ExposureRange {
  static const double min = -4.0;
  static const double max = 4.0;
  static const double step = 0.5;
  static const double defaultValue = 0.0;
}

/// Focus distance range (0.0 = infinity, 1.0 = macro)
class FocusRange {
  static const double min = 0.0;
  static const double max = 1.0;
  static const double defaultValue = 0.5;
}

/// Zoom range
class ZoomRange {
  static const double min = 1.0;
  static const double max = 10.0;
  static const double defaultValue = 1.0;
}

/// White balance temperature presets (in Kelvin)
class WhiteBalancePresets {
  static const int tungsten = 2700;
  static const int fluorescent = 4000;
  static const int daylight = 5500;
  static const int cloudy = 6500;
  static const int shade = 7500;
}

/// HDR bracketing defaults
class HdrDefaults {
  static const int bracketCount = 3;
  static const double evSpacing = 2.0;
  static const List<double> defaultBrackets = [-2.0, 0.0, 2.0];
}

/// Export quality defaults
class ExportDefaults {
  static const int jpegQuality = 95;
  static const String defaultFormat = 'jpeg';
}

/// Processing parameters
class ProcessingDefaults {
  static const double contrastDefault = 0.0;
  static const double vibranceDefault = 0.0;
  static const double clarityDefault = 0.0;
  static const double shadowsDefault = 0.0;
  static const double highlightsDefault = 0.0;
  static const double sharpenDefault = 0.0;
  static const double denoiseDefault = 0.0;
  static const double saturationDefault = 0.0;
  static const double temperatureDefault = 0.0;
}
