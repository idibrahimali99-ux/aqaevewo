/// عنوان PHP API على سيرفر لينكس (نفس تطبيق الزبائن).
class ApiConfig {
  ApiConfig._();

  static const String linuxHost = '212.224.86.115';

  static const String baseUrl = String.fromEnvironment(
    'VEWO_API_BASE',
    defaultValue: 'http://$linuxHost/api',
  );
}
