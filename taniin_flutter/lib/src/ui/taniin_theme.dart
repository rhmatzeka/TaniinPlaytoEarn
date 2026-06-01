import 'package:flutter/material.dart';

class TaniinColors {
  const TaniinColors._();

  static const soil = Color(0xFF8C5A33);
  static const darkSoil = Color(0xFF5B3923);
  static const leaf = Color(0xFF2F7D45);
  static const leafDark = Color(0xFF1F5A36);
  static const grass = Color(0xFF82B55A);
  static const wheat = Color(0xFFF3C763);
  static const cream = Color(0xFFFFF3C7);
  static const ink = Color(0xFF25301F);
  static const panel = Color(0xFFFFE49D);
  static const panelDeep = Color(0xFFE2A746);
  static const blue = Color(0xFF3B75BA);
  static const red = Color(0xFFD45642);
}

ThemeData buildTaniinTheme() {
  const textTheme = TextTheme(
    titleLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
    titleMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
    bodyLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    bodyMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TaniinColors.leaf,
      brightness: Brightness.light,
    ),
    fontFamily: 'monospace',
    textTheme: textTheme.apply(
      bodyColor: TaniinColors.ink,
      displayColor: TaniinColors.ink,
    ),
    scaffoldBackgroundColor: TaniinColors.grass,
  );
}
