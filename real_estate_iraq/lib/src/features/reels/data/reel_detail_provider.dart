import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

final reelDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, reelId) async {
  final id = reelId.trim();
  if (id.isEmpty) return null;
  try {
    final data = await ref.read(vewoApiClientProvider).getJson(
      'reels/detail',
      query: {'id': id},
    );
    final item = data['item'];
    if (item is Map<String, dynamic>) return item;
    if (item is Map) return Map<String, dynamic>.from(item);
    return null;
  } on VewoApiException {
    return null;
  }
});
