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
      title: 'عقار تاون Admin',
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
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(adminFcmBootstrapProvider).start();
              return AdminNotificationWatcher(
                child: child ?? const SizedBox.shrink(),
              );
            },
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
