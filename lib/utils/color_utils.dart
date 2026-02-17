import 'dart:math' as math;
import 'dart:typed_data';

/// Color space conversion and math utilities for image processing.

/// Converts RGB to HSL color space.
/// Returns [h, s, l] where h is 0-360, s and l are 0-1.
List<double> rgbToHsl(int r, int g, int b) {
  final rf = r / 255.0;
  final gf = g / 255.0;
  final bf = b / 255.0;

  final maxC = math.max(rf, math.max(gf, bf));
  final minC = math.min(rf, math.min(gf, bf));
  final delta = maxC - minC;

  double h = 0;
  double s = 0;
  final l = (maxC + minC) / 2;

  if (delta != 0) {
    s = l > 0.5 ? delta / (2 - maxC - minC) : delta / (maxC + minC);

    if (maxC == rf) {
      h = ((gf - bf) / delta) + (gf < bf ? 6 : 0);
    } else if (maxC == gf) {
      h = ((bf - rf) / delta) + 2;
    } else {
      h = ((rf - gf) / delta) + 4;
    }
    h *= 60;
  }

  return [h, s, l];
}

/// Converts HSL to RGB color space.
/// [h] is 0-360, [s] and [l] are 0-1.
/// Returns [r, g, b] in 0-255 range.
List<int> hslToRgb(double h, double s, double l) {
  if (s == 0) {
    final v = (l * 255).round().clamp(0, 255);
    return [v, v, v];
  }

  double hue2rgb(double p, double q, double t) {
    var tt = t;
    if (tt < 0) tt += 1;
    if (tt > 1) tt -= 1;
    if (tt < 1 / 6) return p + (q - p) * 6 * tt;
    if (tt < 1 / 2) return q;
    if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
    return p;
  }

  final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final p = 2 * l - q;
  final hn = h / 360.0;

  return [
    (hue2rgb(p, q, hn + 1 / 3) * 255).round().clamp(0, 255),
    (hue2rgb(p, q, hn) * 255).round().clamp(0, 255),
    (hue2rgb(p, q, hn - 1 / 3) * 255).round().clamp(0, 255),
  ];
}

/// Calculates relative luminance of an RGB color (ITU-R BT.709).
double luminance(int r, int g, int b) {
  return 0.2126 * r / 255.0 + 0.7152 * g / 255.0 + 0.0722 * b / 255.0;
}

/// Clamps an integer to 0-255 range.
int clamp255(int value) => value.clamp(0, 255);

/// Clamps a double to 0.0-1.0 range.
double clamp01(double value) => value.clamp(0.0, 1.0);

/// Linear interpolation between two values.
double lerp(double a, double b, double t) => a + (b - a) * t;

/// Applies a gamma curve to a normalized value (0-1).
double gammaCorrect(double value, double gamma) {
  return math.pow(value.clamp(0.0, 1.0), 1.0 / gamma).toDouble();
}

/// Applies an S-curve contrast adjustment.
/// [factor] controls the strength: 0 = no change, positive = more contrast.
double sCurve(double value, double factor) {
  if (factor == 0) return value;
  final adjusted = value - 0.5;
  final curved =
      0.5 +
      adjusted * (1.0 + factor * 2.0) / (1.0 + (factor * 2.0 * adjusted.abs()));
  return curved.clamp(0.0, 1.0);
}

/// Creates a 3D LUT from raw bytes (assumes 33x33x33 .cube format).
Float32List? parseCubeLut(String cubeContent) {
  final lines = cubeContent.split('\n');
  int size = 0;
  final values = <double>[];

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (trimmed.startsWith('LUT_3D_SIZE')) {
      size = int.parse(trimmed.split(' ').last);
      continue;
    }
    if (trimmed.startsWith('TITLE') ||
        trimmed.startsWith('DOMAIN_MIN') ||
        trimmed.startsWith('DOMAIN_MAX')) {
      continue;
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 3) {
      values.add(double.parse(parts[0]));
      values.add(double.parse(parts[1]));
      values.add(double.parse(parts[2]));
    }
  }

  if (size == 0 || values.isEmpty) return null;
  return Float32List.fromList(values);
}
