import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';
import 'vewo_api_client.dart';

final vewoApiClientProvider = Provider<VewoApiClient>((ref) {
  final client = VewoApiClient(
    getBearerToken: () => ref.read(adminSessionProvider).adminApiToken,
  );
  ref.onDispose(client.close);
  return client;
});
