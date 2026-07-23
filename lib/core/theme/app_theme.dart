import 'package:flutter/material.dart';

class AppColors {
  static const Color orange = Color(0xFFFF7A1A);
  static const Color liveRed = Color(0xFFE53935);
  static const Color disconnectRed = Color(0xFFE53935);

  static const Color backgroundLight = Color(0xFFEFF1F5);
  static const Color cardWhiteLight = Color(0xFFFFFFFF);
  static const Color textDarkLight = Color(0xFF1A1A2E);
  static const Color textGreyLight = Color(0xFF8A8FA3);
  static const Color borderLight = Color(0xFFE3E5EC);

  static const Color backgroundDark = Color(0xFF121218);
  static const Color cardWhiteDark = Color(0xFF1E1F29);
  static const Color textDarkDark = Color(0xFFF0F2F8);
  static const Color textGreyDark = Color(0xFFA0A5BA);
  static const Color borderDark = Color(0xFF2C2D3C);

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? backgroundDark : backgroundLight;

  static Color cardWhite(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? cardWhiteDark : cardWhiteLight;

  static Color textDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textDarkDark : textDarkLight;

  static Color textGrey(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? textGreyDark : textGreyLight;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? borderDark : borderLight;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      cardColor: AppColors.cardWhiteLight,
      dividerColor: AppColors.borderLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.orange,
        brightness: Brightness.light,
        surface: AppColors.cardWhiteLight,
        onSurface: AppColors.textDarkLight,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      cardColor: AppColors.cardWhiteDark,
      dividerColor: AppColors.borderDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.orange,
        brightness: Brightness.dark,
        surface: AppColors.cardWhiteDark,
        onSurface: AppColors.textDarkDark,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
