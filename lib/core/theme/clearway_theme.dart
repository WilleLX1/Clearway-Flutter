import 'package:flutter/material.dart';

abstract final class ClearwayColors {
  static const blue = Color(0xFF1A73E8);
  static const routeBlue = Color(0xFF4285F4);
  static const routeBlueDark = Color(0xFF1967D2);
  static const red = Color(0xFFEA4335);
  static const green = Color(0xFF188038);
  static const amber = Color(0xFFB06000);
  static const text = Color(0xFF202124);
  static const textSecondary = Color(0xFF5F6368);
  static const divider = Color(0xFFDADCE0);
  static const fill = Color(0xFFF1F3F4);
  static const selected = Color(0xFFE8F0FE);
  static const mapBackground = Color(0xFFF8F7F4);
  static const alternateRoute = Color(0xFFBDC1C6);
  static const alternateRouteBorder = Color(0xFF9AA0A6);
}

abstract final class ClearwayTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: ClearwayColors.blue,
          brightness: Brightness.light,
          surface: Colors.white,
        ).copyWith(
          primary: ClearwayColors.blue,
          error: ClearwayColors.red,
          onSurface: ClearwayColors.text,
          outline: ClearwayColors.divider,
          surfaceContainerHighest: ClearwayColors.fill,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ClearwayColors.mapBackground,
      dividerColor: ClearwayColors.divider,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          fontSize: 14,
          color: ClearwayColors.text,
          height: 1.4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ClearwayColors.fill,
        hintStyle: const TextStyle(color: Color(0xFF80868B), fontSize: 13.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ClearwayColors.textSecondary,
        ),
      ),
    );
  }
}
