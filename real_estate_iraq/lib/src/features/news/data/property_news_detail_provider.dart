import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../domain/property_news_models.dart';

final propertyNewsDetailProvider =
    FutureProvider.family<PropertyNewsDetail?, String>((ref, id) async {
  if (id.isEmpty) return null;
  final api = ref.read(vewoApiClientProvider);
  try {
    final j = await api.getJson(
      'app_property_news_get',
      query: {'id': id},
    );
    final raw = j['item'];
    if (raw is Map<String, dynamic>) {
      return PropertyNewsDetail.fromJson(raw);
    }
    if (raw is Map) {
      return PropertyNewsDetail.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  } on VewoApiException {
    return null;
  }
});
