import 'package:permission_handler/permission_handler.dart';

/// Manages camera and storage permission requests.
class PermissionService {
  /// Request all required permissions. Returns true if all granted.
  Future<bool> requestAllPermissions() async {
    final camera = await Permission.camera.request();
    final storage = await Permission.storage.request();
    final photos = await Permission.photos.request();

    return camera.isGranted && (storage.isGranted || photos.isGranted);
  }

  /// Check if camera permission is granted.
  Future<bool> hasCameraPermission() async {
    return await Permission.camera.isGranted;
  }

  /// Check if storage permission is granted.
  Future<bool> hasStoragePermission() async {
    final storage = await Permission.storage.isGranted;
    final photos = await Permission.photos.isGranted;
    return storage || photos;
  }

  /// Open app settings if permissions were permanently denied.
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
