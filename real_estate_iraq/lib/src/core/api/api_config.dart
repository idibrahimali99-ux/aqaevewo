/// عنوان الـ PHP API (مجلد `api` على السيرفر).
///
/// الافتراضي يشير إلى السيرفر العام؛ للتجربة المحلية:
/// `flutter run --dart-define=VEWO_API_BASE=http://10.0.2.2/api`
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'VEWO_API_BASE',
    defaultValue: 'http://31.57.156.84/api',
  );
}
