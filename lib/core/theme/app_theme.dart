import 'package:flutter/material.dart';

/// Centralized theme + color tokens matching the design.
class AppColors {
  static const Color background = Color(0xFFEFF1F5);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color orange = Color(0xFFFF7A1A);
  static const Color liveRed = Color(0xFFE53935);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textGrey = Color(0xFF8A8FA3);
  static const Color border = Color(0xFFE3E5EC);
  static const Color disconnectRed = Color(0xFFE53935);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.orange,
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
