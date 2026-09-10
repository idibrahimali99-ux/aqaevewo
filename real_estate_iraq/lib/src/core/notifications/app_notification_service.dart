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
  Map<String, dynamic>? _pendingLaunchPayload;

  static const headsUpChannelId = 'vewo_heads_up';
  static const uploadChannelId = 'vewo_upload_progress';
  static const legacyChannelId = 'vewo_high_alerts';

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  void setTapHandler(NotificationTapHandler? handler) {
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

  /// يستهلك حمولة فتح التطبيق من إشعار محلي (cold start).
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
        _pendingLaunchPayload = _decodePayload(
          launch?.notificationResponse?.payload,
        );
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
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          headsUpChannelId,
          'تنبيهات فورية',
          description: 'محادثات وموافقات تظهر أعلى الشاشة مثل واتساب',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          uploadChannelId,
          'رفع المنشورات',
          description: 'شريط تقدم الرفع في لوحة الإشعارات',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          legacyChannelId,
          'تنبيهات عقار تاون',
          description: 'تنبيهات المحادثات والتعليقات والردود',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
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
  }) {
    return showHeadsUp(id: id, title: title, body: body, payload: payload);
  }

  Future<void> showHeadsUp({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await init();
      if (!_ready) return;
      const androidDetails = AndroidNotificationDetails(
        headsUpChannelId,
        'تنبيهات فورية',
        channelDescription: 'محادثات وموافقات تظهر أعلى الشاشة مثل واتساب',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.message,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        ticker: 'عقار تاون',
        fullScreenIntent: false,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
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

  Future<void> showRaw({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationDetails android,
    String? payload,
  }) async {
    try {
      await init();
      if (!_ready) return;
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: android,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: false,
          ),
        ),
        payload: payload,
      );
    } catch (_) {}
  }
}
