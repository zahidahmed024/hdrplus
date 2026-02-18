import 'dart:isolate';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../models/effect_preset.dart';

/// High-performance post-processing effects engine.
///
/// All parameter values are normalized to -1..1 or 0..1 (see EffectPreset).
/// Internal scaling is calibrated to produce visually standard results
/// comparable to Lightroom / Snapseed at the same slider positions.
///
/// Pipeline order:
///   1. Denoise (spatial — blur-based)
///   2. Clarity (spatial — large-radius USM on luminance)
///   3. Single-pass color grading: shadows, highlights, contrast, saturation,
///      vibrance, temperature
///   4. Sharpen (spatial — small-radius USM, applied last)
class EffectsEngine {
  /// Apply a complete preset at full resolution. Runs in a background Isolate.
  Future<img.Image> applyPreset(img.Image input, EffectPreset preset) async {
    // Fast-path: skip processing entirely if all values are zero
    if (_allZero(preset)) return input;
    return await Isolate.run(() => _processChain(input, preset));
  }

  /// Apply a preset at preview resolution for fast feedback.
  Future<img.Image> applyPresetPreview(
    img.Image input,
    EffectPreset preset, {
    int maxPreviewDim = 1024,
  }) async {
    // Fast-path: skip processing entirely if all values are zero
    if (_allZero(preset)) return input;
    return await Isolate.run(() {
      img.Image preview = input;
      if (input.width > maxPreviewDim || input.height > maxPreviewDim) {
        final scale =
            maxPreviewDim /
            (input.width > input.height ? input.width : input.height);
        preview = img.copyResize(
          input,
          width: (input.width * scale).round(),
          height: (input.height * scale).round(),
          interpolation: img.Interpolation.linear,
        );
      }
      return _processChain(preview, preset);
    });
  }

  /// Apply a single effect (no Isolate, for quick single-slider preview).
  img.Image applySingleEffect(
    img.Image input,
    String effectName,
    double value,
  ) {
    switch (effectName) {
      case 'contrast':
      case 'vibrance':
      case 'shadows':
      case 'highlights':
      case 'saturation':
      case 'temperature':
        return _singlePassColorGrade(input, {effectName: value});
      case 'clarity':
        return _adjustClarity(input, value);
      case 'sharpen':
        return _sharpen(input, value);
      case 'denoise':
        return _denoise(input, value);
      default:
        return input;
    }
  }

  // ---------------------------------------------------------------------------
  // Pipeline
  // ---------------------------------------------------------------------------

  /// Returns true if every parameter in the preset is at its default (0).
  static bool _allZero(EffectPreset preset) {
    return preset.parameters.every((p) => p.value == 0);
  }

  static img.Image _processChain(img.Image input, EffectPreset preset) {
    var result = input;

    // Phase 1: Denoise (before everything — works on raw data)
    final denoiseVal = preset.getValue('denoise');
    if (denoiseVal > 0) {
      result = _denoise(result, denoiseVal);
    }

    // Phase 2: Clarity (local contrast — before global color grading)
    final clarityVal = preset.getValue('clarity');
    if (clarityVal > 0) {
      result = _adjustClarity(result, clarityVal);
    }

    // Phase 3: Single-pass color grading
    final colorParams = <String, double>{};
    for (final name in [
      'shadows',
      'highlights',
      'contrast',
      'saturation',
      'vibrance',
      'temperature',
    ]) {
      final v = preset.getValue(name);
      if (v != 0) colorParams[name] = v;
    }
    if (colorParams.isNotEmpty) {
      result = _singlePassColorGrade(result, colorParams);
    }

    // Phase 4: Sharpen last (after all tonal changes are done)
    final sharpenVal = preset.getValue('sharpen');
    if (sharpenVal > 0) {
      result = _sharpen(result, sharpenVal);
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Single-pass color grading (all per-pixel effects in ONE loop)
  // ---------------------------------------------------------------------------

  static img.Image _singlePassColorGrade(
    img.Image image,
    Map<String, double> params,
  ) {
    if (params.isEmpty) return image;

    final result = img.Image(width: image.width, height: image.height);

    // --- Pre-compute constants outside the loop ---

    final shadowsVal = params['shadows'] ?? 0.0;
    final highlightsVal = params['highlights'] ?? 0.0;
    final contrastVal = params['contrast'] ?? 0.0;
    final saturationVal = params['saturation'] ?? 0.0;
    final vibranceVal = params['vibrance'] ?? 0.0;
    final temperatureVal = params['temperature'] ?? 0.0;

    final hasContrast = contrastVal != 0;
    final hasShadows = shadowsVal != 0;
    final hasHighlights = highlightsVal != 0;
    final hasSaturation = saturationVal != 0;
    final hasVibrance = vibranceVal != 0;
    final hasTemp = temperatureVal != 0;

    // Contrast: use a moderate factor. At slider=1.0, factor=1.0 (industry standard).
    // The S-curve itself handles the rest.
    final contrastFactor = contrastVal;

    // Saturation: factor = 1 + val*0.8.
    // At +1.0 → 1.8× (strong but not clipping). At -1.0 → 0.2 (near grayscale).
    final satFactor = 1.0 + saturationVal * 0.8;

    // Temperature: shift in units of 0-255.
    // At +1.0 → warm shift of ~15 on R, -15 on B (subtle but visible).
    // At -1.0 → cool shift.
    final tempShiftR = temperatureVal * 15.0 / 255.0;
    final tempShiftG = temperatureVal * 5.0 / 255.0; // slight green in warm
    final tempShiftB = -temperatureVal * 15.0 / 255.0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        double r = pixel.r.toDouble() / 255.0;
        double g = pixel.g.toDouble() / 255.0;
        double b = pixel.b.toDouble() / 255.0;

        // 1. Shadows recovery — selective lift of dark tones only
        if (hasShadows) {
          final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
          // Quadratic mask: 1.0 at lum=0, drops sharply, reaches 0 at lum≥0.5
          // Much more selective than cosine — doesn't bleed into mid-tones.
          final t = (1.0 - (lum * 2.0).clamp(0.0, 1.0));
          final mask = t * t; // quadratic falloff
          final lift = shadowsVal * mask * 0.3;
          r += lift;
          g += lift;
          b += lift;
        }

        // 2. Highlights recovery — selective pulldown of bright tones only
        if (hasHighlights) {
          final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
          // Quadratic mask: 1.0 at lum=1.0, drops sharply, reaches 0 at lum≤0.5
          final t = ((lum * 2.0 - 1.0).clamp(0.0, 1.0));
          final mask = t * t; // quadratic falloff
          final pull = highlightsVal * mask * 0.3;
          r -= pull;
          g -= pull;
          b -= pull;
        }

        // 3. S-curve contrast
        if (hasContrast) {
          r = _applySCurve(r.clamp(0.0, 1.0), contrastFactor);
          g = _applySCurve(g.clamp(0.0, 1.0), contrastFactor);
          b = _applySCurve(b.clamp(0.0, 1.0), contrastFactor);
        }

        // 4. Saturation (luma-preserving)
        if (hasSaturation) {
          final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
          r = lum + satFactor * (r - lum);
          g = lum + satFactor * (g - lum);
          b = lum + satFactor * (b - lum);
        }

        // 5. Vibrance (selective saturation boost — less-saturated pixels get more)
        if (hasVibrance) {
          final maxC = math.max(r, math.max(g, b));
          final minC = math.min(r, math.min(g, b));
          final chroma = maxC - minC;
          // Pixels with low chroma get a stronger boost
          final selectivity = 1.0 - chroma.clamp(0.0, 1.0);
          // Scale: at slider=1.0, desaturated pixels get +0.4 sat boost
          final boost = vibranceVal * selectivity * 0.4;
          final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
          final newSatFactor = 1.0 + boost;
          r = lum + newSatFactor * (r - lum);
          g = lum + newSatFactor * (g - lum);
          b = lum + newSatFactor * (b - lum);
        }

        // 6. Temperature (warm / cool white balance tint)
        if (hasTemp) {
          r += tempShiftR;
          g += tempShiftG;
          b += tempShiftB;
        }

        // Write final pixel (clamped)
        result.setPixelRgb(
          x,
          y,
          (r * 255).round().clamp(0, 255),
          (g * 255).round().clamp(0, 255),
          (b * 255).round().clamp(0, 255),
        );
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // S-curve contrast
  // ---------------------------------------------------------------------------

  /// Standard sigmoidal contrast.
  /// [factor] -1..1 where 0 = no change.
  /// Uses the formula: 0.5 + (x - 0.5) * (k / (k - 1)) / (1 - k * |2x - 1|)
  /// which produces a smooth S-curve that maps 0→0, 0.5→0.5, 1→1.
  static double _applySCurve(double x, double factor) {
    if (factor == 0) return x;
    // Map factor to a 0..0.99 contrast strength (avoiding division by zero)
    final k = factor.clamp(-0.99, 0.99);
    final v = 2.0 * x - 1.0; // map to -1..1
    // Sigmoidal: v / (1 - k * |v|), then map back to 0..1
    final curved = v / (1.0 - k * v.abs());
    return ((curved + 1.0) / 2.0).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Spatial filters (require blur pass — cannot be merged into single-pass)
  // ---------------------------------------------------------------------------

  /// Clarity: large-radius unsharp mask on luminance only.
  /// Enhances local contrast / micro-detail.
  static img.Image _adjustClarity(img.Image image, double value) {
    if (value <= 0) return image;

    // Scale blur radius relative to image size for consistent results
    // at any resolution. Target: ~1% of the smallest dimension.
    final smallDim = math.min(image.width, image.height);
    final baseRadius = (smallDim * 0.02 * value).round().clamp(2, 20);

    // IMPORTANT: gaussianBlur modifies in-place, so blur a COPY
    final blurred = img.gaussianBlur(img.Image.from(image), radius: baseRadius);
    final result = img.Image(width: image.width, height: image.height);
    // Moderate amount — 0..1 maps to 0..0.8 strength
    final amount = value * 0.8;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final orig = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        // Difference on luminance only (preserves color)
        final origLum =
            0.2126 * orig.r.toDouble() +
            0.7152 * orig.g.toDouble() +
            0.0722 * orig.b.toDouble();
        final blurLum =
            0.2126 * blur.r.toDouble() +
            0.7152 * blur.g.toDouble() +
            0.0722 * blur.b.toDouble();

        final lumDiff = (origLum - blurLum) * amount;

        result.setPixelRgb(
          x,
          y,
          (orig.r + lumDiff).round().clamp(0, 255),
          (orig.g + lumDiff).round().clamp(0, 255),
          (orig.b + lumDiff).round().clamp(0, 255),
        );
      }
    }
    return result;
  }

  /// Unsharp mask sharpening (small radius, applied last in the pipeline).
  static img.Image _sharpen(img.Image image, double value) {
    if (value <= 0) return image;
    // IMPORTANT: gaussianBlur modifies in-place, so blur a COPY
    final blurred = img.gaussianBlur(img.Image.from(image), radius: 1);
    final result = img.Image(width: image.width, height: image.height);
    // Amount: 0..1 maps to 0..1.0 (standard USM range)
    final amount = value * 1.0;

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

  /// Edge-preserving noise reduction (bilateral-approximation).
  static img.Image _denoise(img.Image image, double value) {
    if (value <= 0) return image;
    final radius = (value * 3).round().clamp(1, 4);
    // IMPORTANT: gaussianBlur modifies in-place, so blur a COPY
    final blurred = img.gaussianBlur(img.Image.from(image), radius: radius);
    final result = img.Image(width: image.width, height: image.height);
    // Blend strength capped at 0.7 so it never fully replaces the pixel
    final strength = value * 0.7;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final orig = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        // Edge detection: large colour difference = edge, don't smooth
        final diff =
            ((orig.r - blur.r).abs() +
                (orig.g - blur.g).abs() +
                (orig.b - blur.b).abs()) /
            3.0;

        // Only denoise smooth areas; edges keep original detail
        final threshold = 25.0;
        final factor = diff < threshold ? strength : strength * 0.05;

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
