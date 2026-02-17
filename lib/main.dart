import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'services/permission_service.dart';

/// Application entry point.
///
/// Sets up fullscreen immersive mode, requests camera/storage permissions,
/// and launches the HDR+ camera app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive fullscreen mode (hide status bar during camera use)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D0D1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Request permissions
  final permissionService = PermissionService();
  await permissionService.requestAllPermissions();

  runApp(const HdrPlusApp());
}
