import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../domain/property.dart';
import 'property_api_mapper.dart';

final officePropertiesProvider =
    FutureProvider.family<List<Property>, String>((ref, officeId) async {
  final id = officeId.trim();
  if (id.isEmpty) return const [];
  try {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.getJson(
      'properties/list',
      query: {'owner_id': id, 'limit': '200'},
    );
    final raw = data['items'];
    final list = <Property>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          final p = propertyFromApiRow(e);
          if (p != null) list.add(p);
        } else if (e is Map) {
          final p = propertyFromApiRow(Map<String, dynamic>.from(e));
          if (p != null) list.add(p);
        }
      }
    }
    return list;
  } on VewoApiException {
    return const [];
  } catch (_) {
    return const [];
  }
});
