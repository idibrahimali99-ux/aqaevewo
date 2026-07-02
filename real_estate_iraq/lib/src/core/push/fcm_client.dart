import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import '../notifications/app_notification_service.dart';
import '../notifications/notification_router.dart';
import '../../features/auth/data/auth_controller.dart';
import '../../routing/app_router.dart';

final fcmBootstrapProvider = Provider<FcmClient>((ref) => FcmClient(ref));

class FcmClient {
  FcmClient(this._ref);
  final Ref _ref;

  bool _started = false;

  Future<void> start() async {
    if (_started) {
      await _registerCurrentToken();
      return;
    }
    _started = true;

    AppNotificationService.instance.setTapHandler((data) {
      final router = _ref.read(appRouterProvider);
      navigateFromNotificationPayload(router, data);
    });

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      await _registerCurrentToken();

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
        await AppNotificationService.instance.show(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          title: title,
          body: body,
          payload: Map<String, dynamic>.from(msg.data),
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen(_openFromRemoteMessage);
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openFromRemoteMessage(initial);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('FCM start failed: $e');
      }
    }
  }

  void _openFromRemoteMessage(RemoteMessage msg) {
    if (msg.data.isEmpty) return;
    final router = _ref.read(appRouterProvider);
    navigateFromNotificationPayload(
      router,
      Map<String, dynamic>.from(msg.data),
    );
  }

  Future<void> _registerCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    final auth = _ref.read(authControllerProvider);
    if (!auth.isAuthenticated) return;
    final api = _ref.read(vewoApiClientProvider);
    await api.postJson('app/device/register', {
      'token': token,
      'platform': Platform.isAndroid
          ? 'android'
          : (Platform.isIOS ? 'ios' : 'other'),
    });
  }
}
