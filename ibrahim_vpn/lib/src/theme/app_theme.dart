import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const bg = Color(0xFF070B14);
  static const bgElevated = Color(0xFF0E1624);
  static const card = Color(0xFF121A2B);
  static const cardBorder = Color(0xFF243044);
  static const gold = Color(0xFFE8C547);
  static const teal = Color(0xFF00D4AA);
  static const tealDim = Color(0xFF0A3D36);
  static const danger = Color(0xFFFF5C7A);
  static const text = Color(0xFFF4F7FB);
  static const muted = Color(0xFF93A0B5);
  static const info = Color(0xFF6EA8FF);
  static const warn = Color(0xFFFFC857);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.teal,
      secondary: AppColors.gold,
      surface: AppColors.card,
      error: AppColors.danger,
    ),
  );

  final textTheme = GoogleFonts.cairoTextTheme(base.textTheme).apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.cairo(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
