import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

class OfficeSummary {
  const OfficeSummary({
    required this.id,
    required this.fullName,
    required this.displayName,
    required this.phone,
    this.photoUrl = '',
    this.address = '',
    this.officeVerified = false,
  });

  final String id;
  final String fullName;
  /// اسم المكتب التجاري أو الاسم الكامل إن لم يُحدَّد.
  final String displayName;
  final String phone;
  final String photoUrl;
  final String address;
  final bool officeVerified;

  factory OfficeSummary.fromJson(Map<String, dynamic> j) {
    final fn = j['full_name']?.toString() ?? '';
    final dn = j['display_name']?.toString() ?? '';
    final ov = j['office_verified'];
    return OfficeSummary(
      id: j['id']?.toString() ?? '',
      fullName: fn,
      displayName: dn.isNotEmpty ? dn : fn,
      phone: j['phone']?.toString() ?? '',
      photoUrl: j['office_photo_url']?.toString() ?? '',
      address: j['office_address']?.toString() ?? '',
      officeVerified: ov == true || ov == 1 || ov == '1',
    );
  }
}

class OfficeDetail {
  const OfficeDetail({
    required this.id,
    required this.displayName,
    required this.fullName,
    required this.phone,
    this.photoUrl = '',
    this.address = '',
    this.officeVerified = false,
  });

  final String id;
  final String displayName;
  final String fullName;
  final String phone;
  final String photoUrl;
  final String address;
  final bool officeVerified;

  factory OfficeDetail.fromJson(Map<String, dynamic> j) {
    final fn = j['full_name']?.toString() ?? '';
    final dn = j['display_name']?.toString() ?? '';
    final ov = j['office_verified'];
    return OfficeDetail(
      id: j['id']?.toString() ?? '',
      displayName: dn.isNotEmpty ? dn : fn,
      fullName: fn,
      phone: j['phone']?.toString() ?? '',
      photoUrl: j['office_photo_url']?.toString() ?? '',
      address: j['office_address']?.toString() ?? '',
      officeVerified: ov == true || ov == 1 || ov == '1',
    );
  }
}

final approvedOfficesProvider = FutureProvider<List<OfficeSummary>>((ref) async {
  try {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.getJson('offices/list');
    final raw = data['items'];
    if (raw is! List) return const [];
    final out = <OfficeSummary>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(OfficeSummary.fromJson(e));
      } else if (e is Map) {
        out.add(OfficeSummary.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  } on VewoApiException {
    return const [];
  } catch (_) {
    return const [];
  }
});

final officeDetailProvider = FutureProvider.family<OfficeDetail?, String>((ref, officeId) async {
  final id = officeId.trim();
  if (id.isEmpty) return null;
  try {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.getJson('offices/detail', query: {'id': id});
    final o = data['office'];
    if (o is Map<String, dynamic>) {
      return OfficeDetail.fromJson(o);
    }
    if (o is Map) {
      return OfficeDetail.fromJson(Map<String, dynamic>.from(o));
    }
    return null;
  } on VewoApiException {
    return null;
  } catch (_) {
    return null;
  }
});

class ParcelSummary {
  const ParcelSummary({
    required this.id,
    required this.governorate,
    required this.name,
    required this.no,
    this.postsCount = 0,
    this.districtId,
    this.districtName,
  });

  final String id;
  final String governorate;
  final String name;
  final String no;
  final int postsCount;
  final String? districtId;
  final String? districtName;

  String get displayName => no.isNotEmpty ? '$name — $no' : name;

  factory ParcelSummary.fromJson(Map<String, dynamic> j) {
    final did = j['district_id']?.toString().trim();
    return ParcelSummary(
      id: j['id']?.toString() ?? '',
      governorate: j['governorate']?.toString() ?? '',
      name: j['parcel_name']?.toString() ?? '',
      no: j['parcel_no']?.toString() ?? '',
      postsCount: (j['posts_count'] is num)
          ? (j['posts_count'] as num).toInt()
          : int.tryParse('${j['posts_count']}') ?? 0,
      districtId: (did != null && did.isNotEmpty) ? did : null,
      districtName: j['district_name']?.toString(),
    );
  }
}

final parcelsListProvider =
    FutureProvider.autoDispose<List<ParcelSummary>>((ref) async {
  try {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.getJson('parcels/list');
    final raw = data['items'];
    if (raw is! List) return const [];
    final out = <ParcelSummary>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(ParcelSummary.fromJson(e));
      } else if (e is Map) {
        out.add(ParcelSummary.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  } on VewoApiException {
    return const [];
  } catch (_) {
    return const [];
  }
});

/// مجمّع سكني تديره الإدارة (مثل المقاطعة لكن لفئة «مجمع سكني»).
class CompoundSummary {
  const CompoundSummary({
    required this.id,
    required this.governorate,
    required this.name,
    this.photoUrl = '',
    this.postsCount = 0,
    this.districtId,
    this.districtName,
  });

  final String id;
  final String governorate;
  final String name;
  final String photoUrl;
  final int postsCount;
  final String? districtId;
  final String? districtName;

  String get displayName => name;

  factory CompoundSummary.fromJson(Map<String, dynamic> j) {
    final did = j['district_id']?.toString().trim();
    return CompoundSummary(
      id: j['id']?.toString() ?? '',
      governorate: j['governorate']?.toString() ?? '',
      name: j['compound_name']?.toString() ?? '',
      photoUrl: j['photo_url']?.toString() ?? '',
      postsCount: (j['posts_count'] is num)
          ? (j['posts_count'] as num).toInt()
          : int.tryParse('${j['posts_count']}') ?? 0,
      districtId: (did != null && did.isNotEmpty) ? did : null,
      districtName: j['district_name']?.toString(),
    );
  }
}

final compoundsListProvider =
    FutureProvider.autoDispose<List<CompoundSummary>>((ref) async {
  try {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.getJson('compounds/list');
    final raw = data['items'];
    if (raw is! List) return const [];
    final out = <CompoundSummary>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(CompoundSummary.fromJson(e));
      } else if (e is Map) {
        out.add(CompoundSummary.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return out;
  } on VewoApiException {
    return const [];
  } catch (_) {
    return const [];
  }
});
