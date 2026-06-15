import 'package:flutter/material.dart';

/// Zentrale Farben & Theme. Orientiert an iOS-Systemfarben, funktioniert
/// aber auch sauber auf Android (Material 3).
class AppTheme {
  static const Color primary = Color(0xFF0A84FF); // iOS Systemblau
  static const Color green = Color(0xFF34C759);
  static const Color red = Color(0xFFFF3B30);
  static const Color orange = Color(0xFFFF9500);
  static const Color purple = Color(0xFFAF52DE);

  // sanfte Pastelltöne als Tisch-Fläche, dazu eine dunkle Schriftfarbe aus
  // derselben Farbfamilie (gut lesbar, nicht bunt)
  static const List<Color> avatarColors = [
    Color(0xFFD6E4F0), // Blau
    Color(0xFFDCE8DC), // Grün
    Color(0xFFF0E6D6), // Sand
    Color(0xFFEADFEA), // Mauve
    Color(0xFFE6E2DC), // Greige
    Color(0xFFDCE4EC), // Schiefer
    Color(0xFFE8E0D2), // Sandbeige
    Color(0xFFDFE7E2), // Salbei
  ];

  static const List<Color> avatarTextColors = [
    Color(0xFF2C4A66),
    Color(0xFF3A5240),
    Color(0xFF5E4B30),
    Color(0xFF523F54),
    Color(0xFF4A463F),
    Color(0xFF3A4A5A),
    Color(0xFF574B34),
    Color(0xFF3D4F47),
  ];

  static int _idx(String id) => id.hashCode.abs() % avatarColors.length;

  /// Helle Tisch-Fläche für einen Schüler.
  static Color avatarColor(String id) => avatarColors[_idx(id)];

  /// Dunkle, lesbare Schrift-/Symbolfarbe passend zur Fläche.
  static Color avatarTextColor(String id) => avatarTextColors[_idx(id)];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF2F2F7), // iOS Grouped BG
      fontFamily: '.SF Pro Text',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF2F2F7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.white,
      ),
    );
  }
}
