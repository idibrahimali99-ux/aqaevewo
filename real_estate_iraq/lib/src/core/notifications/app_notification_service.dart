import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef NotificationTapHandler = void Function(Map<String, dynamic> data);

class AppNotificationService {
  AppNotificationService._();

  static final instance = AppNotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  NotificationTapHandler? _onTap;

  void setTapHandler(NotificationTapHandler? handler) {
    _onTap = handler;
  }

  Future<void> init() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: android,
        iOS: ios,
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (resp) {
          final raw = resp.payload;
          if (raw == null || raw.trim().isEmpty) return;
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map<String, dynamic>) {
              _onTap?.call(decoded);
            } else if (decoded is Map) {
              _onTap?.call(Map<String, dynamic>.from(decoded));
            }
          } catch (_) {}
        },
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _ready = true;
    } catch (_) {
      // لا نُسقط التطبيق إذا فشل تهيئة الإشعارات على iOS.
      _ready = false;
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await init();
      if (!_ready) return;
      const androidDetails = AndroidNotificationDetails(
        'vewo_high_alerts',
        'تنبيهات عقار تاون',
        channelDescription: 'تنبيهات المحادثات والتعليقات والردود',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload == null ? null : jsonEncode(payload),
      );
    } catch (_) {}
  }
}
