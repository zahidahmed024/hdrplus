import 'dart:isolate';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import '../models/hdr_settings.dart';
import '../utils/image_utils.dart';

/// HDR processing service that performs exposure fusion, tone mapping,
/// sharpening, and denoising using pure Dart (runs in background Isolate).
///
/// Implements a Mertens-style exposure fusion algorithm:
/// 1. (Optional) Align frames
/// 2. Compute quality weights (contrast, saturation, well-exposedness)
/// 3. Blend frames using computed weights
/// 4. Apply tone mapping if requested
/// 5. Apply sharpening and noise reduction
class HdrProcessor {
  /// Process a list of bracketed exposure images into a single HDR result.
  ///
  /// [frames] — list of exposure-bracketed images (typically 3: under, normal, over)
  /// [settings] — HDR processing configuration
  /// [onProgress] — progress callback (0.0 to 1.0)
  ///
  /// Processing runs in a separate Isolate to avoid blocking the UI thread.
  Future<img.Image> process(
    List<img.Image> frames,
    HdrSettings settings, {
    void Function(double progress, String step)? onProgress,
  }) async {
    onProgress?.call(0.0, 'Preparing frames...');

    if (frames.isEmpty) throw ArgumentError('No frames provided');
    if (frames.length == 1) return frames.first;

    // Downscale for processing if images are large (performance optimization)
    onProgress?.call(0.05, 'Downscaling for processing...');
    final originalWidth = frames.first.width;
    final originalHeight = frames.first.height;
    final maxProcessDim = 2048;

    List<img.Image> processFrames;
    final needsUpscale =
        originalWidth > maxProcessDim || originalHeight > maxProcessDim;

    if (needsUpscale) {
      processFrames =
          frames.map((f) => downscaleForProcessing(f, maxProcessDim)).toList();
    } else {
      processFrames = frames;
    }

    // Run heavy processing in an Isolate
    onProgress?.call(0.1, 'Merging exposures...');
    final result = await Isolate.run(() {
      return _mergeExposures(processFrames, settings);
    });

    onProgress?.call(0.7, 'Applying tone mapping...');
    img.Image mapped = result;
    if (settings.toneMappingCurve != ToneMappingCurve.none) {
      mapped = await Isolate.run(() {
        return _applyToneMapping(
          result,
          settings.toneMappingCurve,
          settings.toneMappingGamma,
        );
      });
    }

    // Upscale back to original resolution if needed
    if (needsUpscale) {
      onProgress?.call(0.85, 'Upscaling to full resolution...');
      mapped = upscaleToTarget(mapped, originalWidth, originalHeight);
    }

    onProgress?.call(1.0, 'HDR merge complete');
    return mapped;
  }

  /// Mertens-style exposure fusion: blend multiple exposures using
  /// quality-based weights (contrast, saturation, well-exposedness).
  static img.Image _mergeExposures(
    List<img.Image> frames,
    HdrSettings settings,
  ) {
    final width = frames.first.width;
    final height = frames.first.height;
    final numFrames = frames.length;

    // Compute weight maps for each frame
    final List<List<List<double>>> weights = [];

    for (int f = 0; f < numFrames; f++) {
      final frame = frames[f];
      final weightMap = List.generate(height, (_) => List.filled(width, 0.0));

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = frame.getPixel(x, y);
          final r = pixel.r.toDouble() / 255.0;
          final g = pixel.g.toDouble() / 255.0;
          final b = pixel.b.toDouble() / 255.0;

          // Contrast weight — favors edges and detail
          double contrastW = 1.0;
          if (x > 0 && x < width - 1 && y > 0 && y < height - 1) {
            final gray = 0.299 * r + 0.587 * g + 0.114 * b;
            final pUp = frames[f].getPixel(x, y - 1);
            final pDown = frames[f].getPixel(x, y + 1);
            final pLeft = frames[f].getPixel(x - 1, y);
            final pRight = frames[f].getPixel(x + 1, y);
            final grayUp =
                0.299 * pUp.r / 255.0 +
                0.587 * pUp.g / 255.0 +
                0.114 * pUp.b / 255.0;
            final grayDown =
                0.299 * pDown.r / 255.0 +
                0.587 * pDown.g / 255.0 +
                0.114 * pDown.b / 255.0;
            final grayLeft =
                0.299 * pLeft.r / 255.0 +
                0.587 * pLeft.g / 255.0 +
                0.114 * pLeft.b / 255.0;
            final grayRight =
                0.299 * pRight.r / 255.0 +
                0.587 * pRight.g / 255.0 +
                0.114 * pRight.b / 255.0;
            final laplacian =
                (4 * gray - grayUp - grayDown - grayLeft - grayRight).abs();
            contrastW = laplacian;
          }

          // Saturation weight — favors colorful pixels
          final mean = (r + g + b) / 3.0;
          final saturationW = math.sqrt(
            ((r - mean) * (r - mean) +
                    (g - mean) * (g - mean) +
                    (b - mean) * (b - mean)) /
                3.0,
          );

          // Well-exposedness weight — favors mid-tones (Gaussian centered at 0.5)
          final sigma = 0.2;
          final sigma2 = 2 * sigma * sigma;
          final wellExposedR = math.exp(-((r - 0.5) * (r - 0.5)) / sigma2);
          final wellExposedG = math.exp(-((g - 0.5) * (g - 0.5)) / sigma2);
          final wellExposedB = math.exp(-((b - 0.5) * (b - 0.5)) / sigma2);
          final wellExposednessW = wellExposedR * wellExposedG * wellExposedB;

          // Combine weights (multiply them together)
          weightMap[y][x] =
              (contrastW + 1e-6) *
              (saturationW + 1e-6) *
              (wellExposednessW + 1e-6);
        }
      }

      weights.add(weightMap);
    }

    // Normalize weights so they sum to 1 at each pixel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double sum = 0;
        for (int f = 0; f < numFrames; f++) {
          sum += weights[f][y][x];
        }
        if (sum > 0) {
          for (int f = 0; f < numFrames; f++) {
            weights[f][y][x] /= sum;
          }
        }
      }
    }

    // Blend frames using normalized weights
    final result = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double rSum = 0, gSum = 0, bSum = 0;

        for (int f = 0; f < numFrames; f++) {
          final pixel = frames[f].getPixel(x, y);
          final w = weights[f][y][x];
          rSum += pixel.r.toDouble() * w;
          gSum += pixel.g.toDouble() * w;
          bSum += pixel.b.toDouble() * w;
        }

        result.setPixelRgb(
          x,
          y,
          rSum.round().clamp(0, 255),
          gSum.round().clamp(0, 255),
          bSum.round().clamp(0, 255),
        );
      }
    }

    return result;
  }

  /// Apply tone mapping to the merged HDR image.
  static img.Image _applyToneMapping(
    img.Image image,
    ToneMappingCurve curve,
    double gamma,
  ) {
    final result = img.Image.from(image);

    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        var r = pixel.r.toDouble() / 255.0;
        var g = pixel.g.toDouble() / 255.0;
        var b = pixel.b.toDouble() / 255.0;

        switch (curve) {
          case ToneMappingCurve.reinhard:
            r = _reinhardTonemap(r, gamma);
            g = _reinhardTonemap(g, gamma);
            b = _reinhardTonemap(b, gamma);
            break;
          case ToneMappingCurve.drago:
            r = _dragoTonemap(r, gamma);
            g = _dragoTonemap(g, gamma);
            b = _dragoTonemap(b, gamma);
            break;
          case ToneMappingCurve.filmic:
            r = _filmicTonemap(r);
            g = _filmicTonemap(g);
            b = _filmicTonemap(b);
            break;
          case ToneMappingCurve.none:
            break;
        }

        // Apply gamma correction
        if (gamma != 1.0) {
          r = math.pow(r.clamp(0.0, 1.0), 1.0 / gamma).toDouble();
          g = math.pow(g.clamp(0.0, 1.0), 1.0 / gamma).toDouble();
          b = math.pow(b.clamp(0.0, 1.0), 1.0 / gamma).toDouble();
        }

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

  /// Reinhard tone mapping operator.
  static double _reinhardTonemap(double value, double gamma) {
    return value / (1.0 + value);
  }

  /// Drago tone mapping operator (logarithmic).
  static double _dragoTonemap(double value, double gamma) {
    final bias = 0.85;
    final maxLum = 1.0;
    return math.log(1.0 + value) /
        (math.log(1.0 + maxLum) *
            math.log(
              2.0 +
                  8.0 *
                      math.pow(value / maxLum, math.log(bias) / math.log(0.5)),
            ));
  }

  /// Filmic (Uncharted 2) tone mapping operator.
  static double _filmicTonemap(double x) {
    const a = 0.15;
    const b = 0.50;
    const c = 0.10;
    const d = 0.20;
    const e = 0.02;
    const f = 0.30;
    final mapped =
        ((x * (a * x + c * b) + d * e) / (x * (a * x + b) + d * f)) - e / f;
    const w = 11.2;
    final whiteScale =
        1.0 /
        (((w * (a * w + c * b) + d * e) / (w * (a * w + b) + d * f)) - e / f);
    return mapped * whiteScale;
  }

  /// Apply unsharp mask sharpening.
  static img.Image sharpen(img.Image image, {double amount = 0.5}) {
    if (amount <= 0) return image;

    // Create a blurred version
    final blurred = img.gaussianBlur(image, radius: 2);
    final result = img.Image.from(image);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final orig = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        final r = (orig.r + amount * (orig.r - blur.r)).round().clamp(0, 255);
        final g = (orig.g + amount * (orig.g - blur.g)).round().clamp(0, 255);
        final b = (orig.b + amount * (orig.b - blur.b)).round().clamp(0, 255);

        result.setPixelRgb(x, y, r, g, b);
      }
    }

    return result;
  }

  /// Apply bilateral-style noise reduction (approximation via gaussian blur + edge-aware blend).
  static img.Image denoise(img.Image image, {double strength = 0.5}) {
    if (strength <= 0) return image;

    final radius = (strength * 3).round().clamp(1, 5);
    final blurred = img.gaussianBlur(image, radius: radius);
    final result = img.Image.from(image);

    // Edge-preserving blend: only smooth uniform areas
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final orig = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        // Calculate color difference
        final diff =
            ((orig.r - blur.r).abs() +
                (orig.g - blur.g).abs() +
                (orig.b - blur.b).abs()) /
            3.0;

        // Only denoise if the difference is small (smooth area)
        final threshold = 30.0;
        final factor = diff < threshold ? strength : strength * 0.1;

        final r = (orig.r * (1 - factor) + blur.r * factor).round().clamp(
          0,
          255,
        );
        final g = (orig.g * (1 - factor) + blur.g * factor).round().clamp(
          0,
          255,
        );
        final b = (orig.b * (1 - factor) + blur.b * factor).round().clamp(
          0,
          255,
        );

        result.setPixelRgb(x, y, r, g, b);
      }
    }

    return result;
  }
}
