import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';

/// Image conversion and manipulation utilities.

/// Converts a [img.Image] (from the `image` package) to Flutter's [Image] widget.
Widget imageToFlutterWidget(img.Image image, {BoxFit fit = BoxFit.contain}) {
  final png = img.encodePng(image);
  return Image.memory(Uint8List.fromList(png), fit: fit, gaplessPlayback: true);
}

/// Encodes [img.Image] to PNG bytes.
Uint8List imageToPngBytes(img.Image image) {
  return Uint8List.fromList(img.encodePng(image));
}

/// Encodes [img.Image] to JPEG bytes with given [quality] (0-100).
Uint8List imageToJpegBytes(img.Image image, {int quality = 95}) {
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

/// Decodes bytes to [img.Image].
img.Image? bytesToImage(Uint8List bytes) {
  return img.decodeImage(bytes);
}

/// Downscales an image to fit within [maxDimension] while maintaining aspect ratio.
/// Used during HDR merge for performance — merge at lower resolution, then upscale.
img.Image downscaleForProcessing(img.Image image, int maxDimension) {
  if (image.width <= maxDimension && image.height <= maxDimension) {
    return image;
  }

  final scale =
      maxDimension / (image.width > image.height ? image.width : image.height);
  final newWidth = (image.width * scale).round();
  final newHeight = (image.height * scale).round();

  return img.copyResize(
    image,
    width: newWidth,
    height: newHeight,
    interpolation: img.Interpolation.linear,
  );
}

/// Upscales an image to match [targetWidth] x [targetHeight].
img.Image upscaleToTarget(img.Image image, int targetWidth, int targetHeight) {
  if (image.width == targetWidth && image.height == targetHeight) {
    return image;
  }
  return img.copyResize(
    image,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.cubic,
  );
}

/// Creates a copy of the image for safe mutation.
img.Image cloneImage(img.Image source) {
  return img.Image.from(source);
}

/// Converts image to grayscale for processing calculations.
img.Image toGrayscale(img.Image image) {
  return img.grayscale(image);
}

/// Gets pixel luminance at position (x, y) normalized to 0-1.
double getPixelLuminance(img.Image image, int x, int y) {
  final pixel = image.getPixel(x, y);
  return (0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b) / 255.0;
}

/// Computes the Laplacian (edge/contrast) magnitude at a pixel.
double laplacianAt(img.Image gray, int x, int y) {
  if (x <= 0 || x >= gray.width - 1 || y <= 0 || y >= gray.height - 1) {
    return 0;
  }
  final center = gray.getPixel(x, y).r.toDouble();
  final top = gray.getPixel(x, y - 1).r.toDouble();
  final bottom = gray.getPixel(x, y + 1).r.toDouble();
  final left = gray.getPixel(x - 1, y).r.toDouble();
  final right = gray.getPixel(x + 1, y).r.toDouble();

  return (4 * center - top - bottom - left - right).abs();
}
