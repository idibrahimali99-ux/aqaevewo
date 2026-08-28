enum LogKind { info, success, warn, error, net }

class VpnLogEntry {
  const VpnLogEntry({
    required this.time,
    required this.message,
    required this.kind,
  });

  final DateTime time;
  final String message;
  final LogKind kind;
}

class GeoInfo {
  const GeoInfo({
    required this.ip,
    required this.country,
    required this.countryCode,
    required this.city,
    required this.region,
    required this.isp,
    required this.lat,
    required this.lon,
    required this.timezone,
  });

  final String ip;
  final String country;
  final String countryCode;
  final String city;
  final String region;
  final String isp;
  final double? lat;
  final double? lon;
  final String timezone;

  String get flag {
    if (countryCode.length != 2) return '🌍';
    final a = countryCode.toUpperCase().codeUnits;
    return String.fromCharCodes([
      0x1F1E6 - 65 + a[0],
      0x1F1E6 - 65 + a[1],
    ]);
  }

  String get locationLine {
    final parts = [city, region, country].where((e) => e.trim().isNotEmpty);
    return parts.join(' · ');
  }
}

class ServerProfile {
  const ServerProfile({
    required this.flag,
    required this.countryAr,
    required this.city,
    required this.countryCode,
    required this.host,
    required this.port,
    required this.protocol,
    required this.cipher,
  });

  final String flag;
  final String countryAr;
  final String city;
  final String countryCode;
  final String host;
  final int port;
  final String protocol;
  final String cipher;

  static const germany = ServerProfile(
    flag: '🇩🇪',
    countryAr: 'ألمانيا',
    city: 'Neu-Isenburg',
    countryCode: 'DE',
    host: '212.224.86.115',
    port: 51820,
    protocol: 'WireGuard',
    cipher: 'ChaCha20-Poly1305',
  );
}

enum VpnUiState { disconnected, connecting, connected, disconnecting }
