import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'src/app/admin_app.dart';
import 'src/features/auth/admin_session.dart';
import 'src/features/auth/auth_providers.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {}

  final session = AdminSession();
  try {
    await session.restoreFromPrefs();
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        adminSessionProvider.overrideWith((ref) => session),
      ],
      child: const AdminApp(),
    ),
  );
}
