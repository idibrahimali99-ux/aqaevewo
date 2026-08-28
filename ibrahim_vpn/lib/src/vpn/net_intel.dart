import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

class NetIntel {
  NetIntel._();

  static Future<GeoInfo> fetchLocation() async {
    try {
      return await _fromIpWho();
    } catch (_) {
      return _fromIpApi();
    }
  }

  static Future<GeoInfo> _fromIpWho() async {
    final res = await http
        .get(Uri.parse('https://ipwho.is/'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('ipwho ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['success'] == false) {
      throw Exception('ipwho failed');
    }
    final conn = data['connection'] as Map<String, dynamic>? ?? const {};
    return GeoInfo(
      ip: '${data['ip'] ?? ''}',
      country: '${data['country'] ?? ''}',
      countryCode: '${data['country_code'] ?? ''}',
      city: '${data['city'] ?? ''}',
      region: '${data['region'] ?? ''}',
      isp: '${conn['isp'] ?? conn['org'] ?? ''}',
      lat: (data['latitude'] as num?)?.toDouble(),
      lon: (data['longitude'] as num?)?.toDouble(),
      timezone: '${(data['timezone'] as Map?)?['id'] ?? ''}',
    );
  }

  static Future<GeoInfo> _fromIpApi() async {
    final res = await http
        .get(
          Uri.parse(
            'http://ip-api.com/json/?fields=status,country,countryCode,regionName,city,isp,lat,lon,timezone,query',
          ),
        )
        .timeout(const Duration(seconds: 8));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'success') {
      throw Exception('ip-api failed');
    }
    return GeoInfo(
      ip: '${data['query'] ?? ''}',
      country: '${data['country'] ?? ''}',
      countryCode: '${data['countryCode'] ?? ''}',
      city: '${data['city'] ?? ''}',
      region: '${data['regionName'] ?? ''}',
      isp: '${data['isp'] ?? ''}',
      lat: (data['lat'] as num?)?.toDouble(),
      lon: (data['lon'] as num?)?.toDouble(),
      timezone: '${data['timezone'] ?? ''}',
    );
  }

  static Future<int?> pingMs({
    required String host,
    int port = 443,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      sw.stop();
      await socket.close();
      return sw.elapsedMilliseconds;
    } catch (_) {
      try {
        final res = await http
            .get(Uri.parse('http://$host/api/index.php?r=health'))
            .timeout(const Duration(seconds: 4));
        sw.stop();
        if (res.statusCode >= 200 && res.statusCode < 500) {
          return sw.elapsedMilliseconds;
        }
      } catch (_) {}
      return null;
    }
  }
}
