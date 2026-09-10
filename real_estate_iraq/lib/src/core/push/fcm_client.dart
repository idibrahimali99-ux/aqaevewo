import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../notifications/app_notification_service.dart';
import '../notifications/notification_router.dart';
import '../notifications/pending_notification_nav.dart';
import '../../features/auth/data/auth_controller.dart';
import '../../routing/app_router.dart';
import '../../routing/app_routes.dart';

final fcmBootstrapProvider = Provider<FcmClient>((ref) => FcmClient(ref));

class FcmClient {
  FcmClient(this._ref) {
    _ref.listen(authControllerProvider, (prev, next) {
      if (next.isAuthenticated && !(prev?.isAuthenticated ?? false)) {
        _flushPending();
      }
    });
  }

  final Ref _ref;

  bool _started = false;
  bool _handledInitial = false;

  Future<void> start() async {
    if (_started) {
      await _registerCurrentToken();
      _flushPending();
      return;
    }
    _started = true;

    await AppNotificationService.instance.init();
    AppNotificationService.instance.setTapHandler((data) {
      _openPayload(data, delayMs: 0);
    });

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
        provisional: false,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      await messaging.setAutoInitEnabled(true);

      await _registerCurrentToken();
      // iOS قد يسلّم توكن APNs بعد ثوانٍ من منح الإذن.
      if (Platform.isIOS) {
        Future<void>.delayed(const Duration(seconds: 3), _registerCurrentToken);
        Future<void>.delayed(const Duration(seconds: 10), _registerCurrentToken);
      }

      messaging.onTokenRefresh.listen((t) async {
        try {
          await _registerToken(t);
        } catch (_) {}
      });

      FirebaseMessaging.onMessage.listen((msg) async {
        final n = msg.notification;
        final title = n?.title ?? msg.data['title']?.toString() ?? 'عقار تاون';
        final body = n?.body ?? msg.data['body']?.toString() ?? '';
        if (title.isEmpty && body.isEmpty) return;
        // على iOS النظام يعرض إشعار FCM عبر willPresent — تجنّب التكرار.
        if (Platform.isIOS && n != null) return;
        await AppNotificationService.instance.show(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          title: title,
          body: body,
          payload: Map<String, dynamic>.from(msg.data),
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        _openFromRemoteMessage(msg, delayMs: 200);
      });

      if (!_handledInitial) {
        _handledInitial = true;
        final localLaunch =
            await AppNotificationService.instance.takePendingLaunchPayload();
        if (localLaunch != null && localLaunch.isNotEmpty) {
          _openPayload(localLaunch, delayMs: 900);
        } else {
          final initial = await messaging.getInitialMessage();
          if (initial != null) {
            _openFromRemoteMessage(initial, delayMs: 900);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FCM start failed: $e');
      }
    }
  }

  void _openFromRemoteMessage(RemoteMessage msg, {int delayMs = 300}) {
    final data = Map<String, dynamic>.from(msg.data);
    if (data.isEmpty) {
      // بعض الأجهزة تمرّر العنوان فقط — لا نتجاهل بالكامل.
      final t = msg.notification?.title;
      final b = msg.notification?.body;
      if (t != null) data['title'] = t;
      if (b != null) data['body'] = b;
    }
    if (data.isEmpty) return;
    _openPayload(data, delayMs: delayMs);
  }

  bool _needsAuth(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    return type == 'chat' ||
        type == 'admin_chat' ||
        type == 'property_request' ||
        type == 'property_request_status' ||
        type == 'property_rejected' ||
        type == 'property_approved' ||
        type == 'property_updated' ||
        type == 'property_sold' ||
        type == 'property_urgent_sale' ||
        type == 'reel_comment' ||
        type == 'reel_like' ||
        type == 'reel_approved' ||
        type == 'reel_rejected' ||
        data['thread_id'] != null;
  }

  void _openPayload(Map<String, dynamic> data, {required int delayMs}) {
    PendingNotificationNav.store(data);

    void attempt({required int triesLeft}) {
      try {
        final auth = _ref.read(authControllerProvider);
        final router = _ref.read(appRouterProvider);
        if (_needsAuth(data) && !auth.isAuthenticated) {
          // انتظر اكتمال hydrate أو سجّل الدخول.
          if (triesLeft > 0) {
            Future<void>.delayed(const Duration(milliseconds: 400), () {
              attempt(triesLeft: triesLeft - 1);
            });
            return;
          }
          router.go(AppRoutes.login);
          return;
        }
        final payload = PendingNotificationNav.take() ?? data;
        navigateFromNotificationPayload(router, payload);
      } catch (_) {
        if (triesLeft > 0) {
          Future<void>.delayed(const Duration(milliseconds: 400), () {
            attempt(triesLeft: triesLeft - 1);
          });
        }
      }
    }

    if (delayMs <= 0) {
      attempt(triesLeft: 6);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(Duration(milliseconds: delayMs), () {
        attempt(triesLeft: 6);
      });
    });
  }

  void _flushPending() {
    final pending = PendingNotificationNav.peek();
    if (pending == null || pending.isEmpty) return;
    _openPayload(pending, delayMs: 300);
  }

  Future<void> _registerCurrentToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      if (Platform.isIOS) {
        String? apns;
        for (var i = 0; i < 20; i++) {
          apns = await messaging.getAPNSToken();
          if (apns != null && apns.isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        if (apns == null || apns.isEmpty) return;
      }
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    final api = _ref.read(vewoApiClientProvider);
    await api.postJson('app/device/register', {
      'token': token,
      'platform': Platform.isAndroid
          ? 'android'
          : (Platform.isIOS ? 'ios' : 'other'),
    });
  }
}
