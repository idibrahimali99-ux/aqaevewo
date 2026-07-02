import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../domain/property.dart';
import '../domain/property_category.dart';
import '../domain/property_segment.dart';
import '../../../core/location/location_providers.dart';
import '../../auth/data/auth_controller.dart';
import 'property_api_mapper.dart';

/// قائمة العقارات من السيرفر فقط — بدون منشورات وهمية محلية.
final propertyListingsProvider =
    NotifierProvider<PropertyListingsNotifier, List<Property>>(
      PropertyListingsNotifier.new,
    );

final propertyListingsLoadingProvider = StateProvider<bool>((ref) => true);

class PropertyListingsNotifier extends Notifier<List<Property>> {
  @override
  List<Property> build() {
    Future.microtask(_hydrate);
    return const [];
  }

  static final _uuidLike = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  Future<void> _hydrate() async {
    ref.read(propertyListingsLoadingProvider.notifier).state = true;
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson(
        'properties/list',
        query: const {'limit': '250'},
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
      state = list;
    } catch (_) {
      state = const [];
    } finally {
      ref.read(propertyListingsLoadingProvider.notifier).state = false;
    }
  }

  Future<void> reload() => _hydrate();

  /// إرسال عقار جديد إلى السيرفر. يُرجع `(خطأ، null)` أو `(null, حالة الموافقة)`.
  Future<({String? error, String? approval})> createRemote({
    required String title,
    required String governorate,
    required String addressLine,
    required PropertyCategory category,
    required PropertySegment segment,
    required int priceIqd,
    required int areaSqm,
    required String description,
    String purpose = 'sale',
    Map<String, dynamic>? detailsJson,
    required List<String> imageUrls,
    String? videoUrl,
    String? parcelId,
    String? compoundId,
  }) async {
    try {
      final api = ref.read(vewoApiClientProvider);
      final urls = imageUrls.where((e) => e.trim().isNotEmpty).toList();
      if (urls.isEmpty) {
        return (error: 'أضف صورة واحدة على الأقل', approval: null);
      }
      if (urls.length > 15) {
        return (error: '15 صورة كحد أقصى', approval: null);
      }
      final body = <String, dynamic>{
        'title': title,
        'governorate': governorate,
        'address_line': addressLine,
        'category': category.name,
        'segment': segment.name,
        'purpose': purpose,
        'price_iqd': priceIqd,
        'area_sqm': areaSqm,
        'description': description,
        'image_urls': urls,
      };
      if (detailsJson != null && detailsJson.isNotEmpty) {
        body['details_json'] = detailsJson;
      }
      final v = videoUrl?.trim();
      if (v != null && v.isNotEmpty) {
        body['video_url'] = v;
      }
      final pid = parcelId?.trim();
      if (pid != null && pid.isNotEmpty) {
        body['parcel_id'] = pid;
      }
      final cid = compoundId?.trim();
      if (cid != null && cid.isNotEmpty) {
        body['compound_id'] = cid;
      }
      final data = await api.postJson('properties/create', body);
      final id = data['id']?.toString();
      if (id != null && id.isNotEmpty) {
        ref.read(myListingIdsProvider.notifier).add(id);
      }
      await reload();
      await ref
          .read(authControllerProvider.notifier)
          .refreshPostingFromServer();
      final ap = data['approval_status']?.toString();
      return (error: null, approval: ap ?? 'pending');
    } on VewoApiException catch (e) {
      return (error: e.message, approval: null);
    } catch (_) {
      return (error: 'تعذر الإرسال — تحقق من الجلسة والشبكة', approval: null);
    }
  }

  void addLocal(Property property) {
    state = [...state, property];
  }

  static bool looksLikeServerId(String id) => _uuidLike.hasMatch(id);
}

final allPropertiesProvider = Provider<List<Property>>((ref) {
  final items = ref.watch(propertyListingsProvider);
  final approved = items.where((e) => e.isApproved).toList();
  final sorted = [...approved]
    ..sort((a, b) {
      if (a.isSold != b.isSold) return a.isSold ? 1 : -1;
      final ta = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
  return sorted;
});

final mostViewedProvider = Provider<List<Property>>((ref) {
  final items = ref.watch(allPropertiesProvider);
  final sorted = [...items]
    ..sort((a, b) {
      if (a.isSold != b.isSold) return a.isSold ? 1 : -1;
      return b.views.compareTo(a.views);
    });
  return sorted.take(5).toList();
});

/// الأقرب إلى موقع المستخدم الحالي (إن وُجد).
final nearestToMeProvider = Provider<List<Property>>((ref) {
  final me = ref.watch(currentLatLngProvider);
  if (me == null) return const [];
  final all = ref.watch(allPropertiesProvider);
  final scored = <({Property p, double d})>[];
  for (final p in all) {
    final pos = propertyLatLng(p);
    if (pos == null) continue;
    scored.add((p: p, d: distanceMeters(me, pos)));
  }
  scored.sort((a, b) => a.d.compareTo(b.d));
  return scored.take(8).map((e) => e.p).toList();
});

final topFiveStandardByCategoryProvider =
    Provider.family<List<Property>, PropertyCategory>((ref, category) {
      final items = ref.watch(allPropertiesProvider).where((p) {
        if (p.category != category) return false;
        if (category == PropertyCategory.land ||
            category == PropertyCategory.compound) {
          return p.segment == PropertySegment.standard;
        }
        return true;
      }).toList();
      items.sort((a, b) {
        if (a.isSold != b.isSold) return a.isSold ? 1 : -1;
        return b.views.compareTo(a.views);
      });
      return items.take(5).toList();
    });

final topFiveParcelsProvider =
    Provider.family<List<Property>, PropertyCategory>((ref, category) {
      final items = ref
          .watch(allPropertiesProvider)
          .where(
            (p) =>
                p.category == category && p.segment == PropertySegment.parcel,
          )
          .toList();
      items.sort((a, b) {
        if (a.isSold != b.isSold) return a.isSold ? 1 : -1;
        return b.views.compareTo(a.views);
      });
      return items.take(5).toList();
    });

final propertyByIdProvider = Provider.family<Property?, String>((ref, id) {
  final all = ref.watch(propertyListingsProvider);
  for (final p in all) {
    if (p.id == id) return p;
  }
  return null;
});

/// تفاصيل عقار: من القائمة المحمّلة أو من `properties/get` لمعرّفات UUID.
final propertyDetailProvider = FutureProvider.autoDispose
    .family<Property?, String>((ref, id) async {
      for (final p in ref.watch(propertyListingsProvider)) {
        if (p.id == id) return p;
      }
      if (!PropertyListingsNotifier.looksLikeServerId(id)) {
        return null;
      }
      try {
        final api = ref.read(vewoApiClientProvider);
        final data = await api.getJson('properties/get', query: {'id': id});
        final pmap = data['property'];
        if (pmap is! Map<String, dynamic>) return null;
        final imgsRaw = data['images'];
        final imgs = <String>[];
        if (imgsRaw is List) {
          for (final u in imgsRaw) {
            final s = u?.toString();
            if (s != null && s.isNotEmpty) imgs.add(s);
          }
        }
        return propertyFromApiRow(pmap, imageUrls: imgs.isEmpty ? null : imgs);
      } catch (_) {
        return null;
      }
    });

final myPropertiesProvider = FutureProvider.autoDispose<List<Property>>((
  ref,
) async {
  final auth = ref.watch(authControllerProvider);
  final uid = auth.userId?.trim() ?? '';
  if (!auth.isAuthenticated || uid.isEmpty) return const [];
  final api = ref.read(vewoApiClientProvider);
  final data = await api.getJson(
    'properties/list',
    query: {'owner_id': uid, 'include_mine': '1', 'limit': '250'},
  );
  final raw = data['items'];
  final list = <Property>[];
  if (raw is List) {
    for (final e in raw) {
      final map = e is Map<String, dynamic>
          ? e
          : (e is Map ? Map<String, dynamic>.from(e) : null);
      if (map == null) continue;
      final p = propertyFromApiRow(map);
      if (p != null) list.add(p);
    }
  }
  list.sort((a, b) {
    final ta = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final tb = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return tb.compareTo(ta);
  });
  return list;
});

final myListingIdsProvider =
    NotifierProvider<MyListingIdsNotifier, Set<String>>(
      MyListingIdsNotifier.new,
    );

class MyListingIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void add(String id) => state = {...state, id};
}
