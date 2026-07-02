import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'src/app/admin_app.dart';
import 'src/features/auth/admin_session.dart';
import 'src/features/auth/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  final session = AdminSession();
  await session.restoreFromPrefs();
  runApp(
    ProviderScope(
      overrides: [
        adminSessionProvider.overrideWith((ref) => session),
      ],
      child: const AdminApp(),
    ),
  );
}
