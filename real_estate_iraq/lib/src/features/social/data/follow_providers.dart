import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../properties/domain/property.dart';

class FollowState {
  const FollowState({
    this.officeIds = const {},
    this.compoundIds = const {},
    this.parcelIds = const {},
  });

  final Set<String> officeIds;
  final Set<String> compoundIds;
  final Set<String> parcelIds;

  bool followsOffice(String id) => officeIds.contains(id);
  bool followsCompound(String id) => compoundIds.contains(id);
  bool followsParcel(String id) => parcelIds.contains(id);

  int scoreForProperty(Property p) {
    var s = 0;
    final oid = p.ownerUserId?.trim();
    if (oid != null && oid.isNotEmpty && officeIds.contains(oid)) {
      s += 100;
    }
    if (p.compoundId != null && p.compoundId!.isNotEmpty && compoundIds.contains(p.compoundId)) {
      s += 80;
    }
    if (p.parcelId != null && p.parcelId!.isNotEmpty && parcelIds.contains(p.parcelId)) {
      s += 80;
    }
    final dj = p.detailsJson;
    if (dj != null) {
      final cid = dj['compound_id']?.toString().trim();
      if (cid != null && cid.isNotEmpty && compoundIds.contains(cid)) {
        s += 80;
      }
      final pid = dj['parcel_id']?.toString().trim();
      if (pid != null && pid.isNotEmpty && parcelIds.contains(pid)) {
        s += 80;
      }
    }
    return s;
  }
}

class FollowListNotifier extends AsyncNotifier<FollowState> {
  @override
  Future<FollowState> build() async {
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson('follow/list');
      final raw = data['items'];
      final offices = <String>{};
      final compounds = <String>{};
      final parcels = <String>{};
      if (raw is List) {
        for (final e in raw) {
          final m = e is Map<String, dynamic>
              ? e
              : (e is Map ? Map<String, dynamic>.from(e) : null);
          if (m == null) continue;
          final kind = m['target_kind']?.toString();
          final id = m['target_id']?.toString().trim() ?? '';
          if (id.isEmpty) continue;
          switch (kind) {
            case 'office':
              offices.add(id);
              break;
            case 'compound':
              compounds.add(id);
              break;
            case 'parcel':
              parcels.add(id);
              break;
          }
        }
      }
      return FollowState(
        officeIds: offices,
        compoundIds: compounds,
        parcelIds: parcels,
      );
    } on VewoApiException {
      return const FollowState();
    } catch (_) {
      return const FollowState();
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = AsyncData(await build());
  }

  Future<bool> toggle({
    required String targetKind,
    required String targetId,
  }) async {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.postJson('follow/toggle', {
      'target_kind': targetKind,
      'target_id': targetId,
    });
    await reload();
    return data['following'] == true;
  }
}

final followListProvider =
    AsyncNotifierProvider<FollowListNotifier, FollowState>(
  FollowListNotifier.new,
);

final followStatusProvider = FutureProvider.autoDispose
    .family<({bool following, int followers}), ({String kind, String id})>(
  (ref, arg) async {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.getJson(
      'follow/status',
      query: {'target_kind': arg.kind, 'target_id': arg.id},
    );
    final following = data['following'] == true;
    final fc = data['follower_count'];
    final followers = fc is num ? fc.toInt() : int.tryParse('$fc') ?? 0;
    return (following: following, followers: followers);
  },
);
