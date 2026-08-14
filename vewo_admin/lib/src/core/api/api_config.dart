/// عنوان PHP API (نفس تطبيق الزبائن).
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'VEWO_API_BASE',
    defaultValue: 'http://212.224.86.115/api',
  );
}
