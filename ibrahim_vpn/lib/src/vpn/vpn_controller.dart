import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_wireguard/flutter_wireguard.dart' as wg;

import 'models.dart';
import 'net_intel.dart';
import 'wg_config.dart';

class VpnController extends ChangeNotifier {
  VpnUiState state = VpnUiState.disconnected;
  GeoInfo? location;
  int? pingMs;
  double downloadBps = 0;
  double uploadBps = 0;
  int rxBytes = 0;
  int txBytes = 0;
  DateTime? handshakeAt;
  DateTime? connectedAt;
  String? lastError;
  final List<VpnLogEntry> logs = [];

  Timer? _tick;
  StreamSubscription<wg.TunnelStatus>? _statusSub;
  int _lastRx = 0;
  int _lastTx = 0;
  DateTime? _lastSampleAt;
  int _tickCount = 0;
  bool _busy = false;

  ServerProfile get server => ServerProfile.germany;
  bool get isConnected => state == VpnUiState.connected;
  bool get isBusy =>
      _busy ||
      state == VpnUiState.connecting ||
      state == VpnUiState.disconnecting;

  Duration? get sessionDuration {
    final start = connectedAt;
    if (start == null || !isConnected) return null;
    return DateTime.now().difference(start);
  }

  Future<void> boot() async {
    _log('تشغيل ابراهيم VPN', LogKind.info);
    _log(
      'الخادم: ${server.flag} ${server.countryAr} · ${server.city}',
      LogKind.net,
    );
    await Future.wait([
      refreshLocation(reason: 'فحص الموقع عند الفتح'),
      refreshPing(reason: 'قياس البنغ عند الفتح'),
    ]);
    _listenStatus();
    _startTicker();
  }

  Future<void> toggle() async {
    if (isBusy) return;
    if (isConnected || state == VpnUiState.connecting) {
      await disconnect();
    } else {
      await connect();
    }
  }

  Future<void> connect() async {
    if (_busy) return;
    _busy = true;
    lastError = null;
    state = VpnUiState.connecting;
    _log('طلب اتصال إلى ${server.countryAr} (${server.host})', LogKind.info);
    notifyListeners();
    try {
      _log('تفعيل نفق WireGuard على المنفذ UDP ${server.port}', LogKind.net);
      await wg.start(WgConfig.tunnelName, WgConfig.quickConfig);
      state = VpnUiState.connected;
      connectedAt = DateTime.now();
      _lastRx = 0;
      _lastTx = 0;
      _lastSampleAt = DateTime.now();
      _log('تم الاتصال بنجاح عبر ${server.protocol}', LogKind.success);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      await Future.wait([
        refreshLocation(reason: 'تحديث الموقع بعد الاتصال'),
        refreshPing(reason: 'قياس البنغ بعد الاتصال'),
      ]);
    } catch (e) {
      state = VpnUiState.disconnected;
      connectedAt = null;
      lastError = '$e';
      _log('فشل الاتصال: $e', LogKind.error);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_busy) return;
    _busy = true;
    state = VpnUiState.disconnecting;
    _log('قطع الاتصال...', LogKind.warn);
    notifyListeners();
    try {
      await wg.stop(WgConfig.tunnelName);
      _log('تم قطع الاتصال', LogKind.success);
    } catch (e) {
      lastError = '$e';
      _log('تعذر قطع الاتصال: $e', LogKind.error);
    } finally {
      state = VpnUiState.disconnected;
      connectedAt = null;
      downloadBps = 0;
      uploadBps = 0;
      handshakeAt = null;
      _busy = false;
      notifyListeners();
      await Future.wait([
        refreshLocation(reason: 'تحديث الموقع بعد قطع الاتصال'),
        refreshPing(reason: 'قياس البنغ بعد قطع الاتصال'),
      ]);
    }
  }

  Future<void> refreshLocation({required String reason}) async {
    _log(reason, LogKind.net);
    try {
      final info = await NetIntel.fetchLocation();
      location = info;
      _log(
        'الموقع الحالي: ${info.flag} ${info.locationLine} — IP ${info.ip}',
        LogKind.success,
      );
    } catch (e) {
      _log('تعذر جلب الموقع: $e', LogKind.error);
    }
    notifyListeners();
  }

  Future<void> refreshPing({required String reason}) async {
    _log(reason, LogKind.net);
    final ms = await NetIntel.pingMs(host: server.host, port: 80);
    pingMs = ms;
    if (ms == null) {
      _log('فشل قياس البنغ', LogKind.warn);
    } else {
      _log('البنغ الحالي: $ms ms', LogKind.success);
    }
    notifyListeners();
  }

  void _listenStatus() {
    _statusSub?.cancel();
    _statusSub = wg.statusStream().listen((status) {
      if (status.name != WgConfig.tunnelName) return;
      _applyTunnel(status);
    }, onError: (Object e) {
      _log('خطأ في حالة النفق: $e', LogKind.error);
    });
  }

  void _startTicker() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) async {
      _tickCount++;
      try {
        final status = await wg.status(WgConfig.tunnelName);
        _applyTunnel(status);
      } catch (_) {
        if (state == VpnUiState.connected) {
          downloadBps = 0;
          uploadBps = 0;
        }
      }
      if (_tickCount % 4 == 0) {
        final ms = await NetIntel.pingMs(host: server.host, port: 80);
        if (ms != null) pingMs = ms;
        notifyListeners();
      }
      if (_tickCount % 12 == 0) {
        try {
          location = await NetIntel.fetchLocation();
          notifyListeners();
        } catch (_) {}
      }
    });
  }

  void _applyTunnel(wg.TunnelStatus status) {
    final now = DateTime.now();
    final prevAt = _lastSampleAt;
    final dt = prevAt == null
        ? 1.0
        : (now.difference(prevAt).inMilliseconds / 1000).clamp(0.4, 5.0);

    if (prevAt != null && status.rx >= _lastRx && status.tx >= _lastTx) {
      downloadBps = (status.rx - _lastRx) / dt;
      uploadBps = (status.tx - _lastTx) / dt;
    }

    _lastRx = status.rx;
    _lastTx = status.tx;
    _lastSampleAt = now;
    rxBytes = status.rx;
    txBytes = status.tx;
    if (status.handshake > 0) {
      handshakeAt = DateTime.fromMillisecondsSinceEpoch(status.handshake);
    }

    final up = status.state == wg.TunnelState.up;
    if (up && state != VpnUiState.connecting && state != VpnUiState.connected) {
      state = VpnUiState.connected;
      connectedAt ??= DateTime.now();
    } else if (!up &&
        state == VpnUiState.connected &&
        !_busy) {
      state = VpnUiState.disconnected;
      connectedAt = null;
      downloadBps = 0;
      uploadBps = 0;
    }
    notifyListeners();
  }

  void _log(String message, LogKind kind) {
    logs.insert(
      0,
      VpnLogEntry(time: DateTime.now(), message: message, kind: kind),
    );
    if (logs.length > 80) {
      logs.removeRange(80, logs.length);
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }
}

String formatRate(double bps) {
  if (bps < 1) return '0 B/s';
  const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
  var value = bps;
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  final digits = value >= 100 || i == 0 ? 0 : (value >= 10 ? 1 : 2);
  return '${value.toStringAsFixed(digits)} ${units[i]}';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[i]}';
}

String formatDuration(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}
