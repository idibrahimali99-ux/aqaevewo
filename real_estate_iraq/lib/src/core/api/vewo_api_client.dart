import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class VewoApiException implements Exception {
  VewoApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// عميل JSON لمسارات `index.php?r=...` مع Bearer اختياري بعد تسجيل الدخول.
class VewoApiClient {
  VewoApiClient({
    http.Client? httpClient,
    this.getBearerToken,
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String? Function()? getBearerToken;

  void close() => _http.close();

  Uri _uri(String route, [Map<String, String>? extraQuery]) {
    final q = <String, String>{'r': route, ...?extraQuery};
    return Uri.parse('${ApiConfig.baseUrl}/index.php').replace(queryParameters: q);
  }

  Map<String, String> _authHeaders() {
    final t = getBearerToken?.call()?.trim();
    if (t == null || t.isEmpty) return {};
    return {
      'Authorization': 'Bearer $t',
      'X-Auth-Token': t,
    };
  }

  Map<String, dynamic> _decodeMap(http.Response res) {
    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw VewoApiException('استجابة غير صالحة من السيرفر', statusCode: res.statusCode);
    }
  }

  void _rejectWrongHealthInsteadOfRoute(String route, Map<String, dynamic> decoded) {
    if (route == '' || route == 'health' || route == 'version') return;
    if (!route.startsWith('auth')) return;
    final isHealthShape = decoded['service']?.toString() == 'vewo-api' &&
        decoded.containsKey('db') &&
        decoded.containsKey('time');
    if (isHealthShape && !decoded.containsKey('user')) {
      throw VewoApiException(
        'السيرفر أعاد فحص الاتصال (health) بدل مسار الـAPI. تحقق من VEWO_API_BASE.',
      );
    }
  }

  Future<Map<String, dynamic>> getJson(
    String route, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final res = await _http.get(
      _uri(route, query),
      headers: {
        'Accept': 'application/json',
        ..._authHeaders(),
        ...?headers,
      },
    );
    final decoded = _decodeMap(res);
    if (decoded['ok'] == true) return decoded;
    final err = decoded['error']?.toString() ?? 'طلب غير ناجح';
    throw VewoApiException(err, statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> postJson(
    String route,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    final res = await _http.post(
      _uri(route),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        ..._authHeaders(),
        ...?headers,
      },
      body: jsonEncode(body),
    );
    final decoded = _decodeMap(res);
    if (decoded['ok'] == true) {
      _rejectWrongHealthInsteadOfRoute(route, decoded);
      return decoded;
    }
    final err = decoded['error']?.toString() ?? 'طلب غير ناجح';
    throw VewoApiException(err, statusCode: res.statusCode);
  }

  /// رفع ملف (multipart، الحقل: `file`) — يتطلب جلسة مستخدم.
  Future<Map<String, dynamic>> postMultipartFile(
    String route,
    String fieldName,
    String filePath, {
    Map<String, String>? headers,
  }) async {
    final uri = _uri(route);
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Accept': 'application/json',
      ..._authHeaders(),
      ...?headers,
    });
    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final decoded = _decodeMap(res);
    if (decoded['ok'] == true) return decoded;
    final err = decoded['error']?.toString() ?? 'طلب غير ناجح';
    throw VewoApiException(err, statusCode: res.statusCode);
  }

  /// رفع بايتات (يفيد عند تعدد الصور من المعرض — تجنّب مشاكل مسار `tmp` على أندرويد).
  Future<Map<String, dynamic>> postMultipartBytes(
    String route,
    String fieldName,
    Uint8List bytes,
    String filename, {
    Map<String, String>? headers,
  }) async {
    final uri = _uri(route);
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Accept': 'application/json',
      ..._authHeaders(),
      ...?headers,
    });
    request.files.add(
      http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
    );
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final decoded = _decodeMap(res);
    if (decoded['ok'] == true) return decoded;
    final err = decoded['error']?.toString() ?? 'طلب غير ناجح';
    throw VewoApiException(err, statusCode: res.statusCode);
  }
}
