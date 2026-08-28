import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../notifications/admin_notification_router.dart';
import '../notifications/admin_notification_service.dart';
import '../notifications/pending_admin_notification_nav.dart';
import '../../features/auth/auth_providers.dart';
import '../../routing/admin_router.dart';
import '../../routing/admin_routes.dart';

final adminFcmBootstrapProvider = Provider<AdminFcmClient>(
  (ref) => AdminFcmClient(ref),
);

class AdminFcmClient {
  AdminFcmClient(this._ref) {
    final session = _ref.read(adminSessionProvider);
    session.addListener(() {
      if (session.isAuthenticated) {
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

    await AdminNotificationService.instance.init();
    AdminNotificationService.instance.setTapHandler((data) {
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
      await _registerCurrentToken();
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
        final title =
            n?.title ?? msg.data['title']?.toString() ?? 'تنبيه الإدارة';
        final body = n?.body ?? msg.data['body']?.toString() ?? '';
        if (title.isEmpty && body.isEmpty) return;
        if (Platform.isIOS && n != null) return;
        await AdminNotificationService.instance.show(
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
            await AdminNotificationService.instance.takePendingLaunchPayload();
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
        print('Admin FCM start failed: $e');
      }
    }
  }

  void _openFromRemoteMessage(RemoteMessage msg, {int delayMs = 300}) {
    final data = Map<String, dynamic>.from(msg.data);
    if (data.isEmpty) {
      final t = msg.notification?.title;
      final b = msg.notification?.body;
      if (t != null) data['title'] = t;
      if (b != null) data['body'] = b;
    }
    if (data.isEmpty) return;
    _openPayload(data, delayMs: delayMs);
  }

  void _openPayload(Map<String, dynamic> data, {required int delayMs}) {
    PendingAdminNotificationNav.store(data);

    void attempt({required int triesLeft}) {
      try {
        final session = _ref.read(adminSessionProvider);
        final router = _ref.read(adminRouterProvider);
        if (!session.isAuthenticated) {
          if (triesLeft > 0) {
            Future<void>.delayed(const Duration(milliseconds: 400), () {
              attempt(triesLeft: triesLeft - 1);
            });
            return;
          }
          router.go(AdminRoutes.login);
          return;
        }
        final payload = PendingAdminNotificationNav.take() ?? data;
        navigateFromAdminNotificationPayload(router, payload);
      } catch (_) {
        if (triesLeft > 0) {
          Future<void>.delayed(const Duration(milliseconds: 400), () {
            attempt(triesLeft: triesLeft - 1);
          });
        }
      }
    }

    if (delayMs <= 0) {
      attempt(triesLeft: 8);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(Duration(milliseconds: delayMs), () {
        attempt(triesLeft: 8);
      });
    });
  }

  void _flushPending() {
    final pending = PendingAdminNotificationNav.take();
    if (pending == null || pending.isEmpty) return;
    // أعد التخزين ثم افتح — take أزالها.
    _openPayload(pending, delayMs: 250);
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
    final session = _ref.read(adminSessionProvider);
    if (!session.isAuthenticated) return;
    final api = _ref.read(vewoApiClientProvider);
    await api.postJson('admin/device/register', {
      'token': token,
      'platform': Platform.isAndroid
          ? 'android'
          : (Platform.isIOS ? 'ios' : 'other'),
    });
  }
}
