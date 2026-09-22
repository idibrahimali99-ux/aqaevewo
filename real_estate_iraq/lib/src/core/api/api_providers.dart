import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_controller.dart';
import 'vewo_api_client.dart';

final vewoApiClientProvider = Provider<VewoApiClient>((ref) {
  // لا نراقب AuthState هنا: أي تحديث للجلسة كان يغلق HttpClient أثناء الرفع
  // ويظهر على iOS: "Client is already closed". الرمز يُقرأ عند كل طلب.
  ref.keepAlive();
  final client = VewoApiClient(
    getBearerToken: () => ref.read(authControllerProvider).apiToken?.trim(),
    onUnauthorized: () {
      if (ref.read(authControllerProvider).isAuthenticated) {
        ref.read(authControllerProvider.notifier).signOut();
      }
    },
  );
  ref.onDispose(client.close);
  return client;
});
