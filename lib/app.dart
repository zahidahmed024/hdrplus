import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';

/// HDR+ Camera App — main entry point with dark theme, fullscreen, and routing.
class HdrPlusApp extends StatelessWidget {
  const HdrPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HDR+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFC107),
          secondary: Color(0xFFFFA726),
          surface: Color(0xFF1A1A2E),
          error: Color(0xFFEF5350),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D1A),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFFFFC107),
          inactiveTrackColor: Colors.white12,
          thumbColor: const Color(0xFFFFC107),
          overlayColor: const Color(0xFFFFC107).withOpacity(0.15),
          trackHeight: 2,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF2D2D3A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        useMaterial3: true,
      ),
      home: const CameraScreen(),
    );
  }
}
