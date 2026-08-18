/// عنوان الـ PHP API على سيرفر لينكس.
///
/// الافتراضي: `http://212.224.86.115/api`
/// للتجربة المحلية:
/// - محاكي أندرويد: `flutter run --dart-define=VEWO_API_BASE=http://10.0.2.2/api`
/// - محاكي iOS: `flutter run --dart-define=VEWO_API_BASE=http://127.0.0.1/api`
class ApiConfig {
  ApiConfig._();

  static const String linuxHost = '212.224.86.115';

  static const String baseUrl = String.fromEnvironment(
    'VEWO_API_BASE',
    defaultValue: 'http://$linuxHost/api',
  );
}
