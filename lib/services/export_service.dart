import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../models/export_settings.dart';
import '../utils/image_utils.dart';

/// Handles image export to device storage and gallery.
///
/// Supports JPEG (configurable quality) and 16-bit PNG export.
/// Preserves metadata when possible.
class ExportService {
  /// Export an image with the given settings. Returns the saved file path.
  Future<String?> exportImage(
    img.Image image,
    ExportSettings settings, {
    String? customName,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = customName ?? 'HDRPlus_$timestamp';

      Uint8List bytes;
      String extension;

      switch (settings.format) {
        case ExportFormat.jpeg:
          bytes = imageToJpegBytes(image, quality: settings.jpegQuality);
          extension = 'jpg';
          break;
        case ExportFormat.png16bit:
          bytes = imageToPngBytes(image);
          extension = 'png';
          break;
      }

      // Save to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final hdrDir = Directory(path.join(appDir.path, 'HDRPlus'));
      if (!await hdrDir.exists()) {
        await hdrDir.create(recursive: true);
      }

      final filePath = path.join(hdrDir.path, '$fileName.$extension');
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Also save to device gallery
      await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: settings.jpegQuality,
        name: fileName,
      );

      return filePath;
    } catch (e) {
      return null;
    }
  }

  /// Get all saved HDR images from the app directory.
  Future<List<File>> getSavedImages() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final hdrDir = Directory(path.join(appDir.path, 'HDRPlus'));
      if (!await hdrDir.exists()) return [];

      final files =
          await hdrDir
              .list()
              .where(
                (entity) =>
                    entity is File &&
                    (entity.path.endsWith('.jpg') ||
                        entity.path.endsWith('.png')),
              )
              .cast<File>()
              .toList();

      // Sort by modification date, newest first
      files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );

      return files;
    } catch (e) {
      return [];
    }
  }

  /// Delete a saved image.
  Future<bool> deleteImage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
