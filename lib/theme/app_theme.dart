import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color red = Color(0xFFCC2000);
  static const Color black = Color(0xFF000000);
  static const Color wolfGrey = Color(0xFF6D6E71);
  static const Color white = Color(0xFFFFFFFF);
}

abstract final class AppAssets {
  static const String hollomanLogo =
      'assets/branding/holloman_exterminators.png';
}

ThemeData buildBugManTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.red,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.red,
    onPrimary: AppColors.white,
    secondary: AppColors.black,
    onSecondary: AppColors.white,
    surface: AppColors.white,
    onSurface: AppColors.black,
    outline: AppColors.wolfGrey,
  );

  final baseTheme = ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.white,
    useMaterial3: true,
  );

  return baseTheme.copyWith(
    textTheme: baseTheme.textTheme.apply(
      bodyColor: AppColors.black,
      displayColor: AppColors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.black,
      foregroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
    ),
    dividerColor: AppColors.wolfGrey,
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.red,
      foregroundColor: AppColors.white,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.wolfGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.wolfGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.red, width: 2),
      ),
      filled: true,
      fillColor: AppColors.white,
    ),
  );
}
