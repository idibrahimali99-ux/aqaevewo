import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class VewoApiException implements Exception {
  VewoApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// عميل JSON لـ `index.php?r=...` مع إرفاق **Authorization: Bearer** تلقائياً من جلسة الأدمن.
class VewoApiClient {
  VewoApiClient({
    http.Client? httpClient,
    this.getBearerToken,
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String? Function()? getBearerToken;

  void close() => _http.close();

  Map<String, String> _authHeaders() {
    final t = getBearerToken?.call()?.trim();
    if (t == null || t.isEmpty) return {};
    // بعض استضافات Apache/nginx لا تمرّر Authorization إلى PHP — الـAPI يدعم X-Auth-Token أيضاً.
    return {
      'Authorization': 'Bearer $t',
      'X-Auth-Token': t,
    };
  }

  Uri _uri(String route, [Map<String, String>? extraQuery]) {
    final q = <String, String>{'r': route, ...?extraQuery};
    return Uri.parse('${ApiConfig.baseUrl}/index.php').replace(queryParameters: q);
  }

  Map<String, dynamic> _decodeMap(http.Response res) {
    try {
      var raw = utf8.decode(res.bodyBytes);
      raw = raw.trimLeft();
      if (raw.startsWith('\ufeff')) {
        raw = raw.substring(1);
      }
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      final preview = utf8.decode(res.bodyBytes, allowMalformed: true);
      final short =
          preview.length > 220 ? '${preview.substring(0, 220)}…' : preview;
      final msg = short.trimLeft().startsWith('<')
          ? 'السيرفر أعاد HTML بدل JSON — تحقق من مسار الـAPI أو أخطاء PHP على الخادم.'
          : 'استجابة غير صالحة من السيرفر.';
      throw VewoApiException('$msg\n$short', statusCode: res.statusCode);
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
        'السيرفر أعاد فحص الاتصال (health) بدل مسار تسجيل الدخول. '
        'تحقق من VEWO_API_BASE.',
      );
    }
  }

  Future<Map<String, dynamic>> getJson(
    String route, {
    Map<String, String>? headers,
    Map<String, String>? query,
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
    throw VewoApiException(decoded['error']?.toString() ?? 'طلب غير ناجح',
        statusCode: res.statusCode);
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
    throw VewoApiException(decoded['error']?.toString() ?? 'طلب غير ناجح',
        statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> deleteJson(
    String route, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final res = await _http.delete(
      _uri(route, query),
      headers: {
        'Accept': 'application/json',
        ..._authHeaders(),
        ...?headers,
      },
    );
    final decoded = _decodeMap(res);
    if (decoded['ok'] == true) return decoded;
    throw VewoApiException(decoded['error']?.toString() ?? 'طلب غير ناجح',
        statusCode: res.statusCode);
  }

  /// رفع ملف (صورة/فيديو) إلى `admin/upload` مع Bearer.
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
    throw VewoApiException(decoded['error']?.toString() ?? 'طلب غير ناجح',
        statusCode: res.statusCode);
  }
}
