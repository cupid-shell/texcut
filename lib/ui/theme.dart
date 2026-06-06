import 'package:flutter/material.dart';

/// texcut visual identity — a calm indigo/teal palette with Material 3.
class TexcutTheme {
  static const Color defaultSeed = Color(0xFF4C5BD4);

  /// The accent colours offered in Settings → Appearance.
  static const List<Color> accents = [
    Color(0xFF4C5BD4), // indigo (default)
    Color(0xFF4A6CF7), // brand blue
    Color(0xFF00897B), // teal
    Color(0xFF2E7D32), // green
    Color(0xFF6A1B9A), // purple
    Color(0xFFC2185B), // magenta
    Color(0xFFD84315), // deep orange
    Color(0xFF455A64), // slate
  ];

  static ThemeData light({Color seed = defaultSeed}) =>
      _build(Brightness.light, seed);
  static ThemeData dark({Color seed = defaultSeed}) =>
      _build(Brightness.dark, seed);

  static ThemeData _build(Brightness brightness, Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
