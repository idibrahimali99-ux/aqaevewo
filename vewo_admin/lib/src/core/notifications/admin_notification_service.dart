import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef AdminNotificationTapHandler = void Function(Map<String, dynamic> data);

class AdminNotificationService {
  AdminNotificationService._();

  static final AdminNotificationService instance = AdminNotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  AdminNotificationTapHandler? _onTap;
  Map<String, dynamic>? _pendingLaunchPayload;

  void setTapHandler(AdminNotificationTapHandler? handler) {
    _onTap = handler;
  }

  Map<String, dynamic>? _decodePayload(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> takePendingLaunchPayload() async {
    await init();
    final pending = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    return pending;
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
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _pendingLaunchPayload = _decodePayload(launch?.notificationResponse?.payload);
      }
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (resp) {
          final data = _decodePayload(resp.payload);
          if (data == null) return;
          if (_onTap != null) {
            _onTap!(data);
          } else {
            _pendingLaunchPayload = data;
          }
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
      _ready = false;
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    if (!_ready) await init();
    if (!_ready) return;
    try {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'vewo_high_alerts',
        'تنبيهات لوحة الأدمن',
        channelDescription: 'مكاتب ومحادثات جديدة تحتاج متابعة',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
      ),
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
