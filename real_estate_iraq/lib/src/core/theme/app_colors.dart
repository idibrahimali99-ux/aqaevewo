import 'package:flutter/material.dart';

/// لوحة الألوان المركزية — هوية «عقار تاون | AQAR TOWN».
abstract final class AppColors {
  /// خلفية التطبيق الرئيسية.
  static const Color appBackground = Color(0xFFFFFDF7);

  /// خلفية البطاقات والقوائم.
  static const Color cardBackground = Color(0xFFFFFFFF);

  /// أعلى تدرج الهيدر.
  static const Color headerTop = Color(0xFFF6B60C);

  /// أسفل تدرج الهيدر.
  static const Color headerBottom = Color(0xFFD4A000);

  /// اللون الأساسي للهوية والأيقونات المهمة.
  static const Color brandPrimary = Color(0xFFF6B60C);

  /// لون النص الأساسي.
  static const Color textPrimary = Color(0xFF222222);

  /// لون النص الثانوي.
  static const Color textSecondary = Color(0xFF777777);

  /// لون دبوس الخريطة والأزرار الرئيسية.
  static const Color mapPin = Color(0xFFF6B60C);

  /// إطار الشعار والشريط العلوي/السفلي.
  static const Color frameNavy = textPrimary;

  /// ذهبي التمييز (عناوين، تبويب نشط، شارات).
  static const Color frameGold = mapPin;

  /// ضغط الأزرار الرئيسية.
  static const Color ctaPressed = Color(0xFFB78900);

  /// حدود خفيفة للبحث والبطاقات.
  static const Color borderLight = Color(0xFFEEE5CC);

  /// حدود بطاقة العقار.
  static const Color cardBorder = borderLight;

  /// نصوص بيانات العقار.
  static const Color dataText = textSecondary;

  /// عنصر غير نشط في الشريط السفلي.
  static const Color navInactive = textSecondary;

  /// خلفية الصفحات الفاتحة.
  static const Color surfaceMutedLight = appBackground;

  /// خلفية البطاقات الثانوية والأزرار الشاحبة.
  static const Color surfaceWarm = Color(0xFFFFFAEC);

  /// سطح الوضع الداكن الرئيسي.
  static const Color darkSurface = Color(0xFF17140B);

  /// أدنى سطح في الوضع الداكن.
  static const Color darkSurfaceLowest = Color(0xFF211C10);

  static const Color onBrand = Colors.white;

  static const Color successLight = Color(0xFF1B9C6B);
  static const Color warningLight = Color(0xFFFFB020);

  static const Color successDark = Color(0xFF20C997);
  static const Color warningDark = Color(0xFFFFC857);

  static const Color whatsAppLight = headerBottom;
  static const Color whatsAppDark = Color(0xFF2DD4BF);
}
