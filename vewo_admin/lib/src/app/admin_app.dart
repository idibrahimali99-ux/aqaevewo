import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/admin_theme.dart';
import '../core/theme/admin_theme_mode_provider.dart';
import '../core/notifications/admin_notification_watcher.dart';
import '../core/push/admin_fcm_client.dart';
import '../routing/admin_router.dart';

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);
    final mode = ref.watch(adminThemeModeProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'عقار تاون — لوحة التحكم',
      themeMode: mode,
      theme: AdminTheme.light(),
      darkTheme: AdminTheme.dark(),
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [Locale('ar', 'IQ')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: _AdminBootstrap(
            child: AdminNotificationWatcher(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}

class _AdminBootstrap extends ConsumerStatefulWidget {
  const _AdminBootstrap({required this.child});

  final Widget child;

  @override
  ConsumerState<_AdminBootstrap> createState() => _AdminBootstrapState();
}

class _AdminBootstrapState extends ConsumerState<_AdminBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(adminFcmBootstrapProvider).start());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
