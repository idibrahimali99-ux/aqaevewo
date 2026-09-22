import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'api_config.dart';

class VewoApiException implements Exception {
  VewoApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// عميل JSON لمسارات `index.php?r=...` مع Bearer اختياري بعد تسجيل الدخول.
class VewoApiClient {
  VewoApiClient({
    http.Client? httpClient,
    this.getBearerToken,
    this.onUnauthorized,
  }) : _http = httpClient ?? _newJsonClient();

  final http.Client _http;
  final String? Function()? getBearerToken;
  final void Function()? onUnauthorized;

  static const _uploadTimeout = Duration(minutes: 10);

  static http.Client _newJsonClient() {
    final inner = HttpClient()
      ..idleTimeout = const Duration(seconds: 90)
      ..connectionTimeout = const Duration(seconds: 45)
      ..maxConnectionsPerHost = 6;
    return IOClient(inner);
  }

  static HttpClient _rawUploadHttpClient() {
    return HttpClient()
      ..idleTimeout = const Duration(minutes: 8)
      ..connectionTimeout = const Duration(seconds: 60)
      ..maxConnectionsPerHost = 1
      ..autoUncompress = true;
  }

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
      var raw = utf8.decode(res.bodyBytes, allowMalformed: true).trim();
      if (raw.startsWith('\ufeff')) {
        raw = raw.substring(1).trim();
      }
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start >= 0 && end > start) {
        raw = raw.substring(start, end + 1);
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    throw VewoApiException(
      res.statusCode >= 500
          ? 'تعذر إتمام الطلب من السيرفر. أعد المحاولة.'
          : 'استجابة غير صالحة من السيرفر',
      statusCode: res.statusCode,
    );
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

  bool _shouldRetryTransport(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('already closed') ||
        s.contains('client is closed') ||
        s.contains('connection closed') ||
        s.contains('before full header') ||
        s.contains('connection reset') ||
        s.contains('broken pipe') ||
        s.contains('connection abort') ||
        s.contains('timed out') ||
        s.contains('timeout');
  }

  /// يرفع بدون Expect: 100-continue — كثير من أباتشي/PHP يغلقون الاتصال بسببه.
  Future<http.Response> _sendMultipartOnce(http.MultipartRequest request) async {
    final inner = _rawUploadHttpClient();
    try {
      final ioReq = await inner.openUrl(request.method, request.url);
      ioReq
        ..persistentConnection = false
        ..followRedirects = false
        ..maxRedirects = 0;
      final length = request.contentLength;
      // finalize() يضع Content-Type مع boundary — يجب نسخ الهيدرز بعده وإلا PHP لا يملأ $_FILES.
      final stream = request.finalize();
      request.headers.forEach(ioReq.headers.set);
      final contentType = request.headers['content-type'];
      if (contentType != null && contentType.isNotEmpty) {
        ioReq.headers.set(HttpHeaders.contentTypeHeader, contentType);
      }
      ioReq.headers.set(HttpHeaders.connectionHeader, 'close');
      if (length != null && length >= 0) {
        ioReq.contentLength = length;
      }
      ioReq.headers.removeAll(HttpHeaders.expectHeader);

      await ioReq.addStream(stream);
      final ioRes = await ioReq.close().timeout(_uploadTimeout);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in ioRes.timeout(_uploadTimeout)) {
        builder.add(chunk);
      }
      final headerMap = <String, String>{};
      ioRes.headers.forEach((name, values) {
        headerMap[name] = values.join(',');
      });
      return http.Response.bytes(
        builder.takeBytes(),
        ioRes.statusCode,
        headers: headerMap,
        persistentConnection: false,
      );
    } finally {
      inner.close(force: true);
    }
  }

  Future<http.Response> _sendMultipart(
    http.MultipartRequest Function() buildRequest,
  ) async {
    Object? last;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        final request = buildRequest();
        request.persistentConnection = false;
        return await _sendMultipartOnce(request);
      } catch (e) {
        last = e;
        if (attempt >= 3 || !_shouldRetryTransport(e)) {
          rethrow;
        }
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
      }
    }
    throw last ?? VewoApiException('تعذر الرفع');
  }

  Stream<List<int>> _chunkedBytes(
    Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  ) async* {
    const chunk = 64 * 1024;
    var sent = 0;
    if (bytes.isEmpty) {
      onProgress?.call(0, 0);
      yield const <int>[];
      return;
    }
    for (var i = 0; i < bytes.length; i += chunk) {
      final end = i + chunk > bytes.length ? bytes.length : i + chunk;
      final piece = bytes.sublist(i, end);
      sent += piece.length;
      onProgress?.call(sent, bytes.length);
      yield piece;
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
    if (res.statusCode == 401) {
      onUnauthorized?.call();
      throw VewoApiException(
        decoded['error']?.toString() ?? 'انتهت الجلسة على هذا الجهاز',
        statusCode: 401,
      );
    }
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
    if (res.statusCode == 401) {
      onUnauthorized?.call();
      throw VewoApiException(
        decoded['error']?.toString() ?? 'انتهت الجلسة على هذا الجهاز',
        statusCode: 401,
      );
    }
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
    final file = File(filePath);
    final total = await file.length();
    final res = await _sendMultipart(() {
      var sent = 0;
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll({
        'Accept': 'application/json',
        ..._authHeaders(),
        ...?headers,
      });
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
      return request;
    });
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
    final res = await _sendMultipart(() {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll({
        'Accept': 'application/json',
        ..._authHeaders(),
        ...?headers,
      });
      if (onProgress != null) {
        request.files.add(
          http.MultipartFile(
            fieldName,
            _chunkedBytes(bytes, onProgress),
            bytes.length,
            filename: filename,
          ),
        );
      } else {
        request.files.add(
          http.MultipartFile.fromBytes(
            fieldName,
            bytes,
            filename: filename,
          ),
        );
      }
      return request;
    });
    final decoded = _decodeMap(res);
    if (decoded['ok'] == true) return decoded;
    final err = decoded['error']?.toString() ?? 'طلب غير ناجح';
    throw VewoApiException(err, statusCode: res.statusCode);
  }
}
