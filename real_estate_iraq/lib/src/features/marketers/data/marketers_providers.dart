import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

class MarketerSummary {
  const MarketerSummary({
    required this.id,
    required this.fullName,
    required this.displayName,
    required this.phone,
    this.photoUrl = '',
    this.address = '',
    this.verified = false,
  });

  final String id;
  final String fullName;
  final String displayName;
  final String phone;
  final String photoUrl;
  final String address;
  final bool verified;

  factory MarketerSummary.fromJson(Map<String, dynamic> j) {
    final fn = j['full_name']?.toString() ?? '';
    final dn = j['display_name']?.toString() ?? '';
    final ov = j['office_verified'];
    return MarketerSummary(
      id: j['id']?.toString() ?? '',
      fullName: fn,
      displayName: dn.isNotEmpty ? dn : fn,
      phone: j['phone']?.toString() ?? '',
      photoUrl: j['profile_photo_url']?.toString() ?? '',
      address: j['office_address']?.toString() ?? '',
      verified: ov == true || ov == 1 || ov == '1',
    );
  }
}

class MarketerDetail {
  const MarketerDetail({
    required this.id,
    required this.displayName,
    required this.fullName,
    required this.phone,
    this.photoUrl = '',
    this.address = '',
    this.verified = false,
  });

  final String id;
  final String displayName;
  final String fullName;
  final String phone;
  final String photoUrl;
  final String address;
  final bool verified;

  factory MarketerDetail.fromJson(Map<String, dynamic> j) {
    final fn = j['full_name']?.toString() ?? '';
    final dn = j['display_name']?.toString() ?? '';
    final ov = j['office_verified'];
    return MarketerDetail(
      id: j['id']?.toString() ?? '',
      displayName: dn.isNotEmpty ? dn : fn,
      fullName: fn,
      phone: j['phone']?.toString() ?? '',
      photoUrl: j['profile_photo_url']?.toString() ?? '',
      address: j['office_address']?.toString() ?? '',
      verified: ov == true || ov == 1 || ov == '1',
    );
  }
}

final approvedMarketersProvider = FutureProvider<List<MarketerSummary>>((
  ref,
) async {
  try {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.getJson('marketers/list');
    final raw = data['items'];
    if (raw is! List) return const [];
    final out = <MarketerSummary>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(MarketerSummary.fromJson(e));
      } else if (e is Map) {
        out.add(MarketerSummary.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  } on VewoApiException {
    return const [];
  } catch (_) {
    return const [];
  }
});

final marketerDetailProvider = FutureProvider.family<MarketerDetail?, String>((
  ref,
  marketerId,
) async {
  final id = marketerId.trim();
  if (id.isEmpty) return null;
  try {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.getJson('marketers/detail', query: {'id': id});
    final o = data['marketer'];
    if (o is Map<String, dynamic>) {
      return MarketerDetail.fromJson(o);
    }
    if (o is Map) {
      return MarketerDetail.fromJson(Map<String, dynamic>.from(o));
    }
    return null;
  } on VewoApiException {
    return null;
  } catch (_) {
    return null;
  }
});
