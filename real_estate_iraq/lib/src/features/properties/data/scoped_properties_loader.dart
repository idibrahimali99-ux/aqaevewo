import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../auth/data/auth_controller.dart';
import '../../offices/data/offices_providers.dart';
import '../domain/property.dart';
import 'properties_providers.dart';
import 'property_api_mapper.dart';

List<Property> _parsePropertyList(dynamic raw) {
  final list = <Property>[];
  if (raw is! List) return list;
  for (final e in raw) {
    if (e is Map<String, dynamic>) {
      final p = propertyFromApiRow(e);
      if (p != null) list.add(p);
    } else if (e is Map) {
      final p = propertyFromApiRow(Map<String, dynamic>.from(e));
      if (p != null) list.add(p);
    }
  }
  return list;
}

bool _containsLoose(String source, String needle) {
  final s = source.trim().toLowerCase();
  final n = needle.trim().toLowerCase();
  return s.isNotEmpty && n.isNotEmpty && s.contains(n);
}

List<Property> _filterByParcelId(
  List<Property> list,
  String parcelId, {
  String? parcelName,
}) {
  final pid = parcelId.trim().toLowerCase();
  if (pid.isEmpty) return list;
  final pname = parcelName?.trim().toLowerCase() ?? '';
  return list.where((p) {
    if (p.parcelId != null && p.parcelId!.toLowerCase() == pid) return true;
    final fromJson = p.detailsJson?['parcel_id']?.toString().trim().toLowerCase();
    if (fromJson == pid) return true;
    final jsonName = p.detailsJson?['parcel_name']?.toString() ??
        p.detailsJson?['district_name']?.toString() ??
        '';
    final hay = '${p.title} ${p.addressLine} $jsonName';
    return pname.isNotEmpty && _containsLoose(hay, pname);
  }).toList();
}

List<Property> _filterByCompoundId(
  List<Property> list,
  String compoundId, {
  String? compoundName,
}) {
  final cid = compoundId.trim().toLowerCase();
  if (cid.isEmpty) return list;
  final cname = compoundName?.trim().toLowerCase() ?? '';
  return list.where((p) {
    if (p.compoundId != null && p.compoundId!.toLowerCase() == cid) return true;
    final fromJson = p.detailsJson?['compound_id']?.toString().trim().toLowerCase();
    if (fromJson == cid) return true;
    final jsonName = p.detailsJson?['compound_name']?.toString() ?? '';
    final hay = '${p.title} ${p.addressLine} $jsonName';
    return cname.isNotEmpty && _containsLoose(hay, cname);
  }).toList();
}

Future<List<Property>> fetchParcelProperties(Ref ref, String parcelId) async {
  final id = parcelId.trim();
  if (id.isEmpty) return const [];
  String? parcelName;
  try {
    final parcels = ref.read(parcelsListProvider).valueOrNull ?? const [];
    for (final p in parcels) {
      if (p.id == id) {
        parcelName = p.displayName;
        break;
      }
    }
  } catch (_) {}

  List<Property> fromApi = const [];
  try {
    final api = ref.read(vewoApiClientProvider);
    final auth = ref.read(authControllerProvider);
    final data = await api.getJson(
      'properties/list',
      query: {
        'parcel_id': id,
        'limit': '200',
        if (auth.isAuthenticated && (auth.apiToken ?? '').isNotEmpty)
          'include_mine': '1',
      },
    );
    fromApi = _parsePropertyList(data['items']);
    final filtered = _filterByParcelId(fromApi, id, parcelName: parcelName);
    if (filtered.isNotEmpty) return filtered;
  } on VewoApiException {
    // fallback below
  } catch (_) {}

  if ((parcelName ?? '').trim().isNotEmpty) {
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson(
        'properties/list',
        query: {'q': parcelName!.trim(), 'limit': '200'},
      );
      final byName = _filterByParcelId(
        _parsePropertyList(data['items']),
        id,
        parcelName: parcelName,
      );
      if (byName.isNotEmpty) return byName;
    } catch (_) {}
  }

  try {
    await ref.read(propertyListingsProvider.notifier).reload();
    final all = ref.read(propertyListingsProvider);
    final local = _filterByParcelId(all, id, parcelName: parcelName);
    if (local.isNotEmpty) return local;
  } catch (_) {}

  return fromApi;
}

Future<List<Property>> fetchCompoundProperties(
  Ref ref,
  String compoundId, {
  String? fallbackCompoundName,
}) async {
  final id = compoundId.trim();
  if (id.isEmpty) return const [];
  String? compoundName = fallbackCompoundName?.trim();
  try {
    final compounds = ref.read(compoundsListProvider).valueOrNull ?? const [];
    for (final c in compounds) {
      if (c.id == id) {
        compoundName = c.displayName.trim().isNotEmpty ? c.displayName : compoundName;
        break;
      }
    }
  } catch (_) {}

  List<Property> fromApi = const [];
  try {
    final api = ref.read(vewoApiClientProvider);
    final auth = ref.read(authControllerProvider);
    final data = await api.getJson(
      'properties/list',
      query: {
        'compound_id': id,
        'limit': '200',
        if (auth.isAuthenticated && (auth.apiToken ?? '').isNotEmpty)
          'include_mine': '1',
      },
    );
    fromApi = _parsePropertyList(data['items']);
    final filtered = _filterByCompoundId(fromApi, id, compoundName: compoundName);
    if (filtered.isNotEmpty) return filtered;
  } on VewoApiException {
    // fallback
  } catch (_) {}

  if ((compoundName ?? '').trim().isNotEmpty) {
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson(
        'properties/list',
        query: {'q': compoundName!.trim(), 'limit': '200'},
      );
      final byName = _filterByCompoundId(
        _parsePropertyList(data['items']),
        id,
        compoundName: compoundName,
      );
      if (byName.isNotEmpty) return byName;
    } catch (_) {}
  }

  try {
    await ref.read(propertyListingsProvider.notifier).reload();
    final all = ref.read(propertyListingsProvider);
    final local = _filterByCompoundId(all, id, compoundName: compoundName);
    if (local.isNotEmpty) return local;
  } catch (_) {}

  return fromApi;
}
