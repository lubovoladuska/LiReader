import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Pastel pink and peach accents
  static const Color primaryPink = Color(0xFFF2A7B5);
  static const Color primaryPinkDark = Color(0xFFD88596);
  static const Color accentPeach = Color(0xFFFDC8B7);
  static const Color peachDark = Color(0xFFEAA693);

  // Background and surface colors (Light)
  static const Color lightBg = Color(0xFFFAF8F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF2C2527);
  static const Color lightTextSecondary = Color(0xFF7D7276);
  static const Color lightDivider = Color(0xFFEFE8E9);

  // Background and surface colors (Dark)
  static const Color darkBg = Color(0xFF191617);
  static const Color darkSurface = Color(0xFF231F21);
  static const Color darkCard = Color(0xFF2B2628);
  static const Color darkTextPrimary = Color(0xFFF7F2F3);
  static const Color darkTextSecondary = Color(0xFFA59B9E);
  static const Color darkDivider = Color(0xFF383134);

  // Highlight colors palette for reader
  static const List<Color> highlightColors = [
    Color(0xFFFFEE8C), // Pastel Yellow
    Color(0xFFC7F3C4), // Pastel Mint
    Color(0xFFFFCAD4), // Pastel Rose
    Color(0xFFFFD6BA), // Pastel Peach
    Color(0xFFBEE1E6), // Pastel Sky
    Color(0xFFE2C2FF), // Pastel Lavender
  ];

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryPink,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: primaryPink,
        onPrimary: Colors.white,
        secondary: accentPeach,
        onSecondary: Color(0xFF4A342B),
        surface: lightSurface,
        onSurface: lightTextPrimary,
        surfaceContainerHighest: Color(0xFFF4ECEE),
      ),
      textTheme: baseTextTheme.copyWith(
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: lightTextPrimary,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: lightTextPrimary,
          height: 1.6,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: lightTextSecondary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: lightDivider, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryPinkDark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryPinkDark,
        onPrimary: Colors.white,
        secondary: peachDark,
        onSecondary: Colors.white,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        surfaceContainerHighest: Color(0xFF332D30),
      ),
      textTheme: baseTextTheme.copyWith(
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: darkTextPrimary,
          height: 1.6,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: darkTextSecondary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkDivider, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
      ),
    );
  }
}
