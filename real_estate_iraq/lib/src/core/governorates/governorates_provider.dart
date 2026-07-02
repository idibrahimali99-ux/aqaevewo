import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vewo_shared/vewo_shared.dart' show Iraq;

import '../api/api_providers.dart';

final governoratesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  try {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.getJson('app/governorates');
    final raw = data['items'];
    final out = <String>[];
    if (raw is List) {
      for (final e in raw) {
        final s = e?.toString().trim();
        if (s != null && s.isNotEmpty) out.add(s);
      }
    }
    if (out.isNotEmpty) return out;
  } catch (_) {}
  return Iraq.governorates;
});

/// محافظات مع معرف السيرفر (لربط الأقضية / النواحي).
final governoratesWithIdProvider =
    FutureProvider.autoDispose<List<({String id, String name})>>((ref) async {
  try {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.getJson('app/governorates/full');
    final raw = data['items'];
    final out = <({String id, String name})>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          final id = e['id']?.toString().trim() ?? '';
          final name = e['name']?.toString().trim() ?? '';
          if (id.length >= 32 && name.isNotEmpty) {
            out.add((id: id, name: name));
          }
        } else if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final id = m['id']?.toString().trim() ?? '';
          final name = m['name']?.toString().trim() ?? '';
          if (id.length >= 32 && name.isNotEmpty) {
            out.add((id: id, name: name));
          }
        }
      }
    }
    if (out.isNotEmpty) return out;
  } catch (_) {}
  return const [];
});

/// أقضية / نواحي حسب معرف المحافظة.
final districtsForGovernorateProvider =
    FutureProvider.autoDispose.family<List<({String id, String name})>, String>((
  ref,
  governorateId,
) async {
  final gid = governorateId.trim();
  if (gid.length < 32) return const [];
  try {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.getJson(
      'app/districts/list',
      query: {'governorate_id': gid},
    );
    final raw = data['items'];
    final out = <({String id, String name})>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          final id = e['id']?.toString().trim() ?? '';
          final name = e['name']?.toString().trim() ?? '';
          if (id.length >= 32 && name.isNotEmpty) {
            out.add((id: id, name: name));
          }
        } else if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final id = m['id']?.toString().trim() ?? '';
          final name = m['name']?.toString().trim() ?? '';
          if (id.length >= 32 && name.isNotEmpty) {
            out.add((id: id, name: name));
          }
        }
      }
    }
    return out;
  } catch (_) {
    return const [];
  }
});

