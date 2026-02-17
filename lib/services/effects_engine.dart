import 'dart:isolate';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../models/effect_preset.dart';
import '../utils/color_utils.dart';

/// Modular post-processing effects engine with chainable pipeline.
///
/// Supports effects: contrast, vibrance, clarity, shadows/highlights recovery,
/// saturation, temperature, sharpening, denoising, and LUT application.
///
/// Usage:
/// ```dart
/// final engine = EffectsEngine();
/// final result = await engine.applyPreset(image, preset);
/// ```
class EffectsEngine {
  /// Apply a complete preset (all effects in chain) to an image.
  /// Runs in a background Isolate for performance.
  Future<img.Image> applyPreset(img.Image input, EffectPreset preset) async {
    return await Isolate.run(() {
      return _processChain(input, preset);
    });
  }

  /// Apply a single effect for real-time preview (no Isolate for speed).
  img.Image applySingleEffect(
    img.Image input,
    String effectName,
    double value,
  ) {
    switch (effectName) {
      case 'contrast':
        return _adjustContrast(input, value);
      case 'vibrance':
        return _adjustVibrance(input, value);
      case 'clarity':
        return _adjustClarity(input, value);
      case 'shadows':
        return _recoverShadows(input, value);
      case 'highlights':
        return _recoverHighlights(input, value);
      case 'saturation':
        return _adjustSaturation(input, value);
      case 'temperature':
        return _adjustTemperature(input, value);
      case 'sharpen':
        return _sharpen(input, value);
      case 'denoise':
        return _denoise(input, value);
      default:
        return input;
    }
  }

  /// Full pipeline: HDR → denoise → color grade → sharpen → export
  static img.Image _processChain(img.Image input, EffectPreset preset) {
    var result = img.Image.from(input);

    // 1. Denoise first (works best on clean data before other adjustments)
    final denoiseVal = preset.getValue('denoise');
    if (denoiseVal > 0) {
      result = _denoise(result, denoiseVal);
    }

    // 2. Shadows/Highlights recovery
    final shadowsVal = preset.getValue('shadows');
    if (shadowsVal != 0) {
      result = _recoverShadows(result, shadowsVal);
    }

    final highlightsVal = preset.getValue('highlights');
    if (highlightsVal != 0) {
      result = _recoverHighlights(result, highlightsVal);
    }

    // 3. Contrast
    final contrastVal = preset.getValue('contrast');
    if (contrastVal != 0) {
      result = _adjustContrast(result, contrastVal);
    }

    // 4. Clarity (local contrast)
    final clarityVal = preset.getValue('clarity');
    if (clarityVal > 0) {
      result = _adjustClarity(result, clarityVal);
    }

    // 5. Saturation
    final saturationVal = preset.getValue('saturation');
    if (saturationVal != 0) {
      result = _adjustSaturation(result, saturationVal);
    }

    // 6. Vibrance (selective saturation)
    final vibranceVal = preset.getValue('vibrance');
    if (vibranceVal != 0) {
      result = _adjustVibrance(result, vibranceVal);
    }

    // 7. Temperature
    final temperatureVal = preset.getValue('temperature');
    if (temperatureVal != 0) {
      result = _adjustTemperature(result, temperatureVal);
    }

    // 8. Sharpen last
    final sharpenVal = preset.getValue('sharpen');
    if (sharpenVal > 0) {
      result = _sharpen(result, sharpenVal);
    }

    return result;
  }

  /// S-curve contrast adjustment.
  /// [value] from -1 to 1 (negative = reduce contrast).
  static img.Image _adjustContrast(img.Image image, double value) {
    if (value == 0) return image;
    final result = img.Image.from(image);
    final factor = value * 2.0; // Scale to useful range

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = _applySCurve(pixel.r.toDouble() / 255.0, factor) * 255;
        final g = _applySCurve(pixel.g.toDouble() / 255.0, factor) * 255;
        final b = _applySCurve(pixel.b.toDouble() / 255.0, factor) * 255;
        result.setPixelRgb(
          x,
          y,
          r.round().clamp(0, 255),
          g.round().clamp(0, 255),
          b.round().clamp(0, 255),
        );
      }
    }
    return result;
  }

  static double _applySCurve(double x, double factor) {
    if (factor == 0) return x;
    final centered = x - 0.5;
    final sign = centered >= 0 ? 1.0 : -1.0;
    final absVal = centered.abs();
    final curved =
        0.5 +
        sign *
            math.pow(
              absVal,
              factor > 0 ? 1.0 / (1.0 + factor) : 1.0 + factor.abs(),
            ) *
            0.5 /
            math.pow(
              0.5,
              factor > 0 ? 1.0 / (1.0 + factor) : 1.0 + factor.abs(),
            );
    return curved.clamp(0.0, 1.0);
  }

  /// Vibrance: selectively boosts saturation of less-saturated pixels.
  static img.Image _adjustVibrance(img.Image image, double value) {
    if (value == 0) return image;
    final result = img.Image.from(image);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble() / 255.0;
        final g = pixel.g.toDouble() / 255.0;
        final b = pixel.b.toDouble() / 255.0;

        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        final saturation = maxC == 0 ? 0.0 : (maxC - minC) / maxC;

        // Less saturated pixels get more boost
        final boostFactor = value * (1.0 - saturation);
        final hsl = rgbToHsl(
          (r * 255).round(),
          (g * 255).round(),
          (b * 255).round(),
        );

        final newSat = (hsl[1] + boostFactor).clamp(0.0, 1.0);
        final rgb = hslToRgb(hsl[0], newSat, hsl[2]);

        result.setPixelRgb(x, y, rgb[0], rgb[1], rgb[2]);
      }
    }
    return result;
  }

  /// Clarity: local contrast enhancement using unsharp mask on luminance.
  static img.Image _adjustClarity(img.Image image, double value) {
    if (value <= 0) return image;

    // Large-radius unsharp mask on luminance channel only
    final blurred = img.gaussianBlur(
      image,
      radius: (10 * value).round().clamp(3, 15),
    );
    final result = img.Image.from(image);
    final amount = value * 1.5;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final orig = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        // Apply clarity to luminance only, preserve chrominance
        final origLum =
            0.299 * orig.r.toDouble() +
            0.587 * orig.g.toDouble() +
            0.114 * orig.b.toDouble();
        final blurLum =
            0.299 * blur.r.toDouble() +
            0.587 * blur.g.toDouble() +
            0.114 * blur.b.toDouble();

        final lumDiff = (origLum - blurLum) * amount;

        final r = (orig.r + lumDiff).round().clamp(0, 255);
        final g = (orig.g + lumDiff).round().clamp(0, 255);
        final b = (orig.b + lumDiff).round().clamp(0, 255);

        result.setPixelRgb(x, y, r, g, b);
      }
    }
    return result;
  }

  /// Shadows recovery: lifts dark regions without affecting highlights.
  static img.Image _recoverShadows(img.Image image, double value) {
    if (value == 0) return image;
    final result = img.Image.from(image);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble() / 255.0;
        final g = pixel.g.toDouble() / 255.0;
        final b = pixel.b.toDouble() / 255.0;
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;

        // Only affect dark regions (lum < 0.5)
        final shadowMask =
            math.pow(1.0 - lum.clamp(0.0, 0.5) * 2.0, 2.0).toDouble();
        final lift = value * shadowMask * 0.5;

        result.setPixelRgb(
          x,
          y,
          ((r + lift) * 255).round().clamp(0, 255),
          ((g + lift) * 255).round().clamp(0, 255),
          ((b + lift) * 255).round().clamp(0, 255),
        );
      }
    }
    return result;
  }

  /// Highlights recovery: compresses bright regions.
  static img.Image _recoverHighlights(img.Image image, double value) {
    if (value == 0) return image;
    final result = img.Image.from(image);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble() / 255.0;
        final g = pixel.g.toDouble() / 255.0;
        final b = pixel.b.toDouble() / 255.0;
        final lum = 0.299 * r + 0.587 * g + 0.114 * b;

        // Only affect bright regions (lum > 0.5)
        final highlightMask =
            math.pow((lum.clamp(0.5, 1.0) - 0.5) * 2.0, 2.0).toDouble();
        final pull = value * highlightMask * 0.5;

        result.setPixelRgb(
          x,
          y,
          ((r - pull) * 255).round().clamp(0, 255),
          ((g - pull) * 255).round().clamp(0, 255),
          ((b - pull) * 255).round().clamp(0, 255),
        );
      }
    }
    return result;
  }

  /// Global saturation adjustment.
  static img.Image _adjustSaturation(img.Image image, double value) {
    if (value == 0) return image;
    final result = img.Image.from(image);
    final factor = 1.0 + value;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        final gray = 0.299 * r + 0.587 * g + 0.114 * b;

        result.setPixelRgb(
          x,
          y,
          (gray + factor * (r - gray)).round().clamp(0, 255),
          (gray + factor * (g - gray)).round().clamp(0, 255),
          (gray + factor * (b - gray)).round().clamp(0, 255),
        );
      }
    }
    return result;
  }

  /// White balance / temperature adjustment.
  /// Positive = warmer (more yellow/red), negative = cooler (more blue).
  static img.Image _adjustTemperature(img.Image image, double value) {
    if (value == 0) return image;
    final result = img.Image.from(image);
    final amount = value * 30; // Scale to color shift range

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        result.setPixelRgb(
          x,
          y,
          (pixel.r + amount).round().clamp(0, 255),
          pixel.g.toInt(),
          (pixel.b - amount).round().clamp(0, 255),
        );
      }
    }
    return result;
  }

  /// Unsharp mask sharpening.
  static img.Image _sharpen(img.Image image, double value) {
    if (value <= 0) return image;
    final blurred = img.gaussianBlur(image, radius: 2);
    final result = img.Image.from(image);
    final amount = value * 2.0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final orig = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        result.setPixelRgb(
          x,
          y,
          (orig.r + amount * (orig.r - blur.r)).round().clamp(0, 255),
          (orig.g + amount * (orig.g - blur.g)).round().clamp(0, 255),
          (orig.b + amount * (orig.b - blur.b)).round().clamp(0, 255),
        );
      }
    }
    return result;
  }

  /// Edge-preserving noise reduction.
  static img.Image _denoise(img.Image image, double value) {
    if (value <= 0) return image;
    final radius = (value * 3).round().clamp(1, 5);
    final blurred = img.gaussianBlur(image, radius: radius);
    final result = img.Image.from(image);
    final strength = value;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final orig = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        final diff =
            ((orig.r - blur.r).abs() +
                (orig.g - blur.g).abs() +
                (orig.b - blur.b).abs()) /
            3.0;

        final factor = diff < 30 ? strength : strength * 0.1;

        result.setPixelRgb(
          x,
          y,
          (orig.r * (1 - factor) + blur.r * factor).round().clamp(0, 255),
          (orig.g * (1 - factor) + blur.g * factor).round().clamp(0, 255),
          (orig.b * (1 - factor) + blur.b * factor).round().clamp(0, 255),
        );
      }
    }
    return result;
  }
}
