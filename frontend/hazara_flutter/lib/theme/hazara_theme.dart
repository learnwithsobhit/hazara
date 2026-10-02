import 'package:flutter/material.dart';

class HazaraColors {
  static const felt = Color(0xFF14382F);
  static const feltDeep = Color(0xFF0C241E);
  static const feltRaised = Color(0xFF1E4E41);
  static const line = Color(0xFF4E7A6C);
  static const cream = Color(0xFFF7F2E8);
  static const creamMuted = Color(0xFFD7E6DE);
  static const ink = Color(0xFF1B1712);
  static const gold = Color(0xFFE6C36A);
  static const you = Color(0xFF9AD8CB);
}

ThemeData hazaraTheme() {
  const cream = HazaraColors.cream;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: HazaraColors.feltDeep,
    colorScheme: const ColorScheme.dark(
      primary: HazaraColors.gold,
      onPrimary: HazaraColors.ink,
      surface: HazaraColors.felt,
      onSurface: cream,
    ),
    fontFamily: 'Georgia',
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: cream, fontSize: 14, height: 1.3),
      bodySmall: TextStyle(
        color: HazaraColors.creamMuted,
        fontSize: 12,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        color: cream,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
  );
}
