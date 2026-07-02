import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// يفتح شاشة تسجيل الدخول بدل رسالة منبثقة فقط.
void openLoginScreen(BuildContext context) {
  context.push(AppRoutes.login);
}

void openRegisterScreen(BuildContext context) {
  context.push(AppRoutes.register);
}
