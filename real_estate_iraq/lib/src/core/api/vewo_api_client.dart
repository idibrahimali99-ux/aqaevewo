import 'dart:convert';
import 'dart:io';
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
        'السيرفر أعاد فحص الاتصال بدل مسار الـAPI. تحقق من عنوان الخادم.',
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
    String? filename,
    Map<String, String>? headers,
    void Function(int sent, int total)? onProgress,
  }) async {
    final uri = _uri(route);
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Accept': 'application/json',
      ..._authHeaders(),
      ...?headers,
    });
    final file = File(filePath);
    final total = await file.length();
    var sent = 0;
    final stream = file.openRead().map((chunk) {
      sent += chunk.length;
      onProgress?.call(sent, total);
      return chunk;
    });
    request.files.add(
      http.MultipartFile(
        fieldName,
        stream,
        total,
        filename: filename,
      ),
    );
    request.persistentConnection = true;
    final streamed = await _http.send(request);
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
    void Function(int sent, int total)? onProgress,
  }) async {
    final uri = _uri(route);
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll({
      'Accept': 'application/json',
      ..._authHeaders(),
      ...?headers,
    });
    var sent = 0;
    const chunk = 256 * 1024;
    final stream = Stream<List<int>>.fromIterable(() {
      final parts = <List<int>>[];
      for (var i = 0; i < bytes.length; i += chunk) {
        final end = i + chunk > bytes.length ? bytes.length : i + chunk;
        parts.add(bytes.sublist(i, end));
      }
      if (parts.isEmpty) parts.add(const <int>[]);
      return parts;
    }()).map((piece) {
      sent += piece.length;
      onProgress?.call(sent, bytes.length);
      return piece;
    });
    request.files.add(
      http.MultipartFile(
        fieldName,
        stream,
        bytes.length,
        filename: filename,
      ),
    );
    request.persistentConnection = true;
    final streamed = await _http.send(request);
    final res = await http.Response.fromStream(streamed);
    final decoded = _decodeMap(res);
    if (decoded['ok'] == true) return decoded;
    final err = decoded['error']?.toString() ?? 'طلب غير ناجح';
    throw VewoApiException(err, statusCode: res.statusCode);
  }
}
