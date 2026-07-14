import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_shape.dart';

/// ثيم موحّد مبني على هوية «عقار تاون | AQAR TOWN» وخط Tajawal.
class AppTheme {
  static ColorScheme _lightScheme() {
    return ColorScheme.fromSeed(
      seedColor: AppColors.brandPrimary,
      brightness: Brightness.light,
      primary: AppColors.brandPrimary,
      onPrimary: AppColors.onBrand,
      secondary: AppColors.frameGold,
      onSecondary: AppColors.onBrand,
      surface: AppColors.cardBackground,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.dataText,
      surfaceContainerLowest: AppColors.surfaceMutedLight,
      surfaceContainerHigh: AppColors.surfaceWarm,
      outlineVariant: AppColors.borderLight,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
  }

  static ColorScheme _darkScheme() {
    return ColorScheme.fromSeed(
      seedColor: AppColors.brandPrimary,
      brightness: Brightness.dark,
      primary: AppColors.frameGold,
      onPrimary: AppColors.onBrand,
      secondary: AppColors.frameGold,
      surface: AppColors.darkSurface,
      surfaceContainerLowest: AppColors.darkSurfaceLowest,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = GoogleFonts.tajawalTextTheme();
    return base.copyWith(
      displaySmall: const TextStyle(fontWeight: FontWeight.w900, height: 1.15),
      headlineMedium: const TextStyle(
        fontWeight: FontWeight.w900,
        height: 1.18,
      ),
      titleLarge: const TextStyle(fontWeight: FontWeight.w900, height: 1.2),
      titleMedium: const TextStyle(fontWeight: FontWeight.w800, height: 1.25),
      titleSmall: const TextStyle(fontWeight: FontWeight.w800, height: 1.25),
      bodyLarge: TextStyle(
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: scheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: scheme.onSurface,
      ),
      bodySmall: TextStyle(
        fontWeight: FontWeight.w400,
        height: 1.35,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: const TextStyle(fontWeight: FontWeight.w800, height: 1.2),
      labelMedium: const TextStyle(fontWeight: FontWeight.w800, height: 1.2),
      labelSmall: const TextStyle(fontWeight: FontWeight.w800, height: 1.2),
    );
  }

  static AppBarTheme _brandAppBarTheme({required bool dark}) {
    return AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: dark ? AppColors.darkSurfaceLowest : AppColors.headerTop,
      foregroundColor: dark ? AppColors.onBrand : AppColors.textPrimary,
      iconTheme: IconThemeData(
        color: dark ? AppColors.onBrand : AppColors.textPrimary,
      ),
      actionsIconTheme: IconThemeData(
        color: dark ? AppColors.onBrand : AppColors.textPrimary,
      ),
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.tajawal(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: dark ? AppColors.onBrand : AppColors.textPrimary,
      ),
    );
  }

  static ThemeData light() {
    final scheme = _lightScheme();

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      textTheme: _textTheme(scheme),
      fontFamily: GoogleFonts.tajawal().fontFamily,
      splashFactory: InkSparkle.splashFactory,
    );

    final radius = AppShape.borderMd;
    final radiusLg = AppShape.borderLg;

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      iconTheme: const IconThemeData(color: AppColors.brandPrimary),
      appBarTheme: _brandAppBarTheme(dark: false),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 3,
        height: 72,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer.withValues(alpha: 0.72),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary.withValues(alpha: 0.08);
          }
          return null;
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
          );
        }),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: AppColors.frameNavy,
        surfaceTintColor: Colors.transparent,
        elevation: 14,
        shadowColor: Colors.black45,
        shape: const CircularNotchedRectangle(),
        padding: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              elevation: 0,
              backgroundColor: AppColors.frameGold,
              foregroundColor: AppColors.onBrand,
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return AppColors.ctaPressed;
                }
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.frameGold.withValues(alpha: 0.38);
                }
                return AppColors.frameGold;
              }),
              foregroundColor: WidgetStateProperty.all(AppColors.onBrand),
              elevation: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return 0.0;
                if (states.contains(WidgetState.pressed)) return 0.0;
                return 1.2;
              }),
              shadowColor: WidgetStateProperty.all(
                AppColors.frameGold.withValues(alpha: 0.35),
              ),
            ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              elevation: 0,
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ).copyWith(
              elevation: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return 0.0;
                if (states.contains(WidgetState.pressed)) return 0.0;
                return 1.2;
              }),
              shadowColor: WidgetStateProperty.all(
                scheme.primary.withValues(alpha: 0.28),
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.appBackground,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.frameGold,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppShape.borderSm),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppShape.borderXs),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surface;
        }),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          fontSize: 16,
        ),
        subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13,
          height: 1.35,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
        elevation: 6,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: radiusLg),
        backgroundColor: scheme.surface,
        elevation: 8,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppShape.bottomSheetTop),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.mapPin, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radiusLg,
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        largeSize: 18,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.frameGold,
        foregroundColor: AppColors.onBrand,
        elevation: 8,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.ctaPressed, width: 1.4),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: scheme.primaryContainer.withValues(alpha: 0.4),
      ),
      extensions: <ThemeExtension<dynamic>>[
        VewoExtras(
          success: AppColors.successLight,
          warning: AppColors.warningLight,
          whatsApp: AppColors.whatsAppLight,
        ),
      ],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData dark() {
    final scheme = _darkScheme();

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      textTheme: _textTheme(scheme),
      fontFamily: GoogleFonts.tajawal().fontFamily,
      splashFactory: InkSparkle.splashFactory,
    );

    final radius = AppShape.borderMd;
    final radiusLg = AppShape.borderLg;

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      iconTheme: const IconThemeData(color: AppColors.brandPrimary),
      appBarTheme: _brandAppBarTheme(dark: true),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 3,
        height: 72,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer.withValues(alpha: 0.72),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary.withValues(alpha: 0.08);
          }
          return null;
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
          );
        }),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: AppColors.frameNavy,
        surfaceTintColor: Colors.transparent,
        elevation: 14,
        shadowColor: Colors.black45,
        shape: const CircularNotchedRectangle(),
        padding: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              elevation: 0,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: radius),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ).copyWith(
              elevation: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return 0.0;
                if (states.contains(WidgetState.pressed)) return 0.0;
                return 1.2;
              }),
              shadowColor: WidgetStateProperty.all(
                scheme.primary.withValues(alpha: 0.35),
              ),
            ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: radius),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ).copyWith(
              elevation: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return 0.0;
                if (states.contains(WidgetState.pressed)) return 0.0;
                return 1.2;
              }),
              shadowColor: WidgetStateProperty.all(
                scheme.primary.withValues(alpha: 0.28),
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppShape.borderSm),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        showCheckmark: false,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        textColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          fontSize: 16,
        ),
        subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 13,
          height: 1.35,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
        elevation: 6,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: radiusLg),
        backgroundColor: scheme.surface,
        elevation: 8,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppShape.bottomSheetTop),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        largeSize: 18,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: scheme.primaryContainer.withValues(alpha: 0.4),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radiusLg,
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppShape.borderXs),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surface;
        }),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.onBrand,
        elevation: 8,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.frameGold, width: 2.2),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        VewoExtras(
          success: AppColors.successDark,
          warning: AppColors.warningDark,
          whatsApp: AppColors.whatsAppDark,
        ),
      ],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// ألوان مساندة (نجاح، تنبيه، واتساب) خارج [ColorScheme].
class VewoExtras extends ThemeExtension<VewoExtras> {
  const VewoExtras({
    required this.success,
    required this.warning,
    required this.whatsApp,
  });

  final Color success;
  final Color warning;
  final Color whatsApp;

  @override
  VewoExtras copyWith({Color? success, Color? warning, Color? whatsApp}) {
    return VewoExtras(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      whatsApp: whatsApp ?? this.whatsApp,
    );
  }

  @override
  VewoExtras lerp(ThemeExtension<VewoExtras>? other, double t) {
    if (other is! VewoExtras) return this;
    return VewoExtras(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      whatsApp: Color.lerp(whatsApp, other.whatsApp, t) ?? whatsApp,
    );
  }
}
