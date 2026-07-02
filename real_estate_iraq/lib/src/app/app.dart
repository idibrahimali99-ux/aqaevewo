import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme.dart';
import '../core/notifications/app_notification_watcher.dart';
import '../core/push/fcm_client.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../routing/app_router.dart';
import '../features/auth/data/auth_controller.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).hydrateFromDisk();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'عقار تاون | AQAR TOWN',
      themeMode: mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('ar', 'IQ'),
      supportedLocales: const [Locale('ar', 'IQ')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => AppNotificationWatcher(
        child: Consumer(
          builder: (context, ref, _) {
            // يبدأ تسجيل FCM token بعد تسجيل الدخول.
            ref.watch(fcmBootstrapProvider).start();
            return OnboardingGate(
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.noScaling),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        ),
      ),
      routerConfig: router,
    );
  }
}
