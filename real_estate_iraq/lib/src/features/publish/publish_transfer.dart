import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/notifications/app_notification_service.dart';

/// إشعار رفع مستمر في لوحة الإشعارات + إبقاء العملية حيّة خارج التطبيق.
class PublishTransferHud {
  PublishTransferHud._();

  static const _progressId = 71001;
  static const _doneId = 71002;
  static const _iosChannel = MethodChannel('com.aqartown.app/upload_keep_alive');

  static DateTime _lastUi = DateTime.fromMillisecondsSinceEpoch(0);
  static int _lastSent = 0;
  static DateTime _lastSpeedAt = DateTime.now();
  static double _bps = 0;
  static bool _fg = false;

  static double get bytesPerSecond => _bps;

  static String formatBytes(int n) {
    if (n <= 0) return '0 بايت';
    const units = ['بايت', 'ك.ب', 'م.ب', 'ج.ب'];
    var v = n.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    final digits = i == 0 ? 0 : (v >= 10 ? 1 : 2);
    return '${v.toStringAsFixed(digits)} ${units[i]}';
  }

  static String formatSpeed(double bps) {
    if (bps <= 0) return '…';
    return '${formatBytes(bps.round())}/ث';
  }

  static void noteBytes(int sent) {
    final now = DateTime.now();
    final dt = now.difference(_lastSpeedAt).inMilliseconds;
    if (dt >= 350) {
      final delta = sent - _lastSent;
      if (delta >= 0) {
        _bps = delta * 1000 / math.max(dt, 1);
      }
      _lastSent = sent;
      _lastSpeedAt = now;
    }
  }

  static Future<void> start(String title) async {
    _lastSent = 0;
    _bps = 0;
    _lastSpeedAt = DateTime.now();
    await AppNotificationService.instance.init();
    if (!kIsWeb && Platform.isIOS) {
      try {
        await _iosChannel.invokeMethod<void>('begin');
      } catch (_) {}
    }
    await _pushProgress(
      title: title,
      body: 'جاري الرفع…',
      progress: 0,
      max: 100,
      indeterminate: true,
    );
  }

  static Future<void> progress({
    required String title,
    required String label,
    required int sent,
    required int total,
    required double fraction,
  }) async {
    noteBytes(sent);
    final now = DateTime.now();
    if (now.difference(_lastUi).inMilliseconds < 280 && fraction < 0.99) {
      return;
    }
    _lastUi = now;
    final pct = (fraction.clamp(0, 1) * 100).round();
    final sizeLine = total > 0
        ? '${formatBytes(sent)} / ${formatBytes(total)}  •  ${formatSpeed(_bps)}'
        : formatSpeed(_bps);
    await _pushProgress(
      title: title,
      body: '$label\n$sizeLine',
      progress: pct,
      max: 100,
      indeterminate: total <= 0,
    );
  }

  static Future<void> succeed(String message) async {
    await _stopFg();
    await AppNotificationService.instance.showHeadsUp(
      id: _doneId,
      title: 'تم الرفع بنجاح',
      body: message,
    );
  }

  static Future<void> fail(String message) async {
    await _stopFg();
    await AppNotificationService.instance.showHeadsUp(
      id: _doneId,
      title: 'تعذر الرفع',
      body: message,
    );
  }

  static Future<void> _pushProgress({
    required String title,
    required String body,
    required int progress,
    required int max,
    required bool indeterminate,
  }) async {
    final android = AndroidNotificationDetails(
      AppNotificationService.uploadChannelId,
      'رفع المنشورات',
      channelDescription: 'شريط تقدم رفع الصور والفيديو',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: max,
      progress: progress,
      indeterminate: indeterminate,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      category: AndroidNotificationCategory.progress,
      visibility: NotificationVisibility.public,
      channelShowBadge: false,
    );
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final plugin = AppNotificationService.instance.plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await plugin?.startForegroundService(
          id: _progressId,
          title: title,
          body: body,
          notificationDetails: android,
          startType: AndroidServiceStartType.startSticky,
          foregroundServiceTypes: {
            AndroidServiceForegroundType.foregroundServiceTypeDataSync,
          },
        );
        _fg = true;
        return;
      } catch (_) {}
    }
    await AppNotificationService.instance.showRaw(
      id: _progressId,
      title: title,
      body: body,
      android: android,
    );
  }

  static Future<void> _stopFg() async {
    if (!kIsWeb && Platform.isIOS) {
      try {
        await _iosChannel.invokeMethod<void>('end');
      } catch (_) {}
    }
    if (_fg) {
      try {
        await AppNotificationService.instance.plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.stopForegroundService();
      } catch (_) {}
      _fg = false;
    }
    try {
      await AppNotificationService.instance.plugin.cancel(id: _progressId);
    } catch (_) {}
  }
}
