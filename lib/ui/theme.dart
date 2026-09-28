import 'package:flutter/material.dart';

/// Farmelo renkleri: toprak, çayır, saman ve ahşap tonları.
class FarmColors {
  static const soil = Color(0xFF8A5A3B);
  static const soilDark = Color(0xFF6B4029);
  static const soilWet = Color(0xFF523020);
  static const grass = Color(0xFF7DBA4B);
  static const grassDark = Color(0xFF5C9A35);
  static const meadow = Color(0xFFA8D66B);
  static const straw = Color(0xFFF2C94C);
  static const wood = Color(0xFFB9784A);
  static const woodDark = Color(0xFF8C5530);
  static const paper = Color(0xFFFFF8EA);
  static const cream = Color(0xFFF7EBD3);
  static const ink = Color(0xFF3D2A1E);
  static const inkSoft = Color(0xFF7A6553);
  static const barnRed = Color(0xFFC8553D);
  static const water = Color(0xFF4AA3DF);
  static const up = Color(0xFF3E9B4F);
  static const down = Color(0xFFD0503C);
}

ThemeData buildFarmTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: FarmColors.grass,
      primary: FarmColors.grassDark,
      secondary: FarmColors.straw,
      surface: FarmColors.paper,
    ),
    scaffoldBackgroundColor: FarmColors.cream,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: FarmColors.ink,
      displayColor: FarmColors.ink,
    ),
  );
}
