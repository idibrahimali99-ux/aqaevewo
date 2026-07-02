import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/presentation/admin_login_screen.dart';
import '../features/shell/admin_console_screen.dart';
import 'admin_routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'adminRoot');

final adminRouterProvider = Provider<GoRouter>((ref) {
  // نفس مثيل AdminSession من main (override) — لا تستخدم .notifier هنا.
  final session = ref.read(adminSessionProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation:
        session.isAuthenticated ? AdminRoutes.console : AdminRoutes.login,
    refreshListenable: session,
    redirect: (context, state) {
      final loggedIn = session.isAuthenticated;
      final onLogin = state.matchedLocation == AdminRoutes.login;
      if (!loggedIn && !onLogin) return AdminRoutes.login;
      if (loggedIn && onLogin) return AdminRoutes.console;
      return null;
    },
    routes: [
      GoRoute(
        path: AdminRoutes.login,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const AdminLoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AdminRoutes.console,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const AdminConsoleScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            );
          },
        ),
      ),
    ],
  );
});
