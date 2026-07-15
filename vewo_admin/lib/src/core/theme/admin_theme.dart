import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// مظهر لوحة تحكم عقار تاون — ذهبي فاخر + خط Tajawal.
class AdminTheme {
  AdminTheme._();

  static const Color brandPrimary = Color(0xFFF6B60C);
  static const Color frameGold = Color(0xFFF6B60C);
  static const Color textPrimary = Color(0xFF222222);
  static const Color textSecondary = Color(0xFF777777);
  static const Color border = Color(0xFFEEE5CC);
  static const Color scaffoldLight = Color(0xFFFFFDF7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color scaffoldDark = Color(0xFF18140A);
  static const Color surfaceDark = Color(0xFF211A0C);
  static const Color surfaceHighDark = Color(0xFF2A220F);
  static const Color onSurfaceDark = Color(0xFFFFF8E7);
  static const Color onSurfaceVariantDark = Color(0xFFE1D4B3);

  static TextTheme _textTheme(ColorScheme scheme, Brightness brightness) {
    final base = brightness == Brightness.dark
        ? GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme)
        : GoogleFonts.tajawalTextTheme(ThemeData.light().textTheme);
    return base
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          headlineSmall: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
            height: 1.2,
          ),
          titleLarge: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.15,
            height: 1.2,
          ),
          titleMedium: const TextStyle(fontWeight: FontWeight.w800),
          bodyLarge: const TextStyle(height: 1.45, fontWeight: FontWeight.w500),
          bodyMedium: const TextStyle(
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: Brightness.dark,
      primary: brandPrimary,
      onPrimary: textPrimary,
      secondary: frameGold,
      onSecondary: textPrimary,
      surface: surfaceDark,
      onSurface: onSurfaceDark,
      surfaceContainerHighest: surfaceHighDark,
      onSurfaceVariant: onSurfaceVariantDark,
      outline: const Color(0xFF5A4A24),
      error: const Color(0xFFFF6B6B),
      onError: const Color(0xFF1A0000),
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: GoogleFonts.tajawal().fontFamily,
      textTheme: _textTheme(scheme, Brightness.dark),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: scaffoldDark,
      drawerTheme: const DrawerThemeData(
        backgroundColor: surfaceDark,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        selectedColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHighDark,
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHighDark,
        contentTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: 0.10),
        ),
        headingTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
        dataTextStyle: TextStyle(color: scheme.onSurface),
        dividerThickness: 0.7,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceHighDark,
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 26),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 24,
        ),
        selectedLabelTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: scheme.primary,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: scheme.onSurfaceVariant,
        ),
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surfaceDark,
        foregroundColor: frameGold,
        iconTheme: const IconThemeData(color: frameGold),
        titleTextStyle: GoogleFonts.tajawal(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: frameGold,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceHighDark,
        elevation: 2,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHighDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.35),
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: surfaceDark,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandPrimary,
        foregroundColor: textPrimary,
      ),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: Brightness.light,
      primary: brandPrimary,
      onPrimary: textPrimary,
      secondary: frameGold,
      onSecondary: textPrimary,
      surface: surfaceLight,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerHighest: scaffoldLight,
      outlineVariant: border,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: GoogleFonts.tajawal().fontFamily,
      textTheme: _textTheme(scheme, Brightness.light),
      scaffoldBackgroundColor: scaffoldLight,
      drawerTheme: const DrawerThemeData(
        backgroundColor: surfaceLight,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        selectedColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scaffoldLight,
        selectedColor: brandPrimary.withValues(alpha: 0.18),
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          brandPrimary.withValues(alpha: 0.12),
        ),
        headingTextStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w900,
        ),
        dividerThickness: 0.7,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: surfaceLight,
        foregroundColor: textPrimary,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.tajawal(
          fontSize: 19,
          fontWeight: FontWeight.w900,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 26),
        unselectedIconTheme: IconThemeData(
          color: scheme.onSurfaceVariant,
          size: 24,
        ),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brandPrimary, width: 1.6),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brandPrimary,
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          elevation: 0,
        ),
      ),
      dividerTheme: const DividerThemeData(color: border),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandPrimary,
        foregroundColor: textPrimary,
      ),
    );
  }
}
