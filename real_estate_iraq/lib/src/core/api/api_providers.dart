import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_controller.dart';
import 'vewo_api_client.dart';

final vewoApiClientProvider = Provider<VewoApiClient>((ref) {
  // إعادة بناء العميل عند تغيّر الجلسة؛ الرمز يُقرأ عبر read عند كل طلب (لا watch داخل الـclosure).
  ref.watch(authControllerProvider);
  final client = VewoApiClient(
    getBearerToken: () => ref.read(authControllerProvider).apiToken?.trim(),
  );
  ref.onDispose(client.close);
  return client;
});
