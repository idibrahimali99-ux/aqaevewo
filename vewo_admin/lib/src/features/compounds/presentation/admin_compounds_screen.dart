import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

final _adminGovernoratesProvider =
    FutureProvider<List<({String id, String name})>>((ref) async {
      try {
        final api = ref.read(vewoApiClientProvider);
        final data = await api.getJson('admin_governorates');
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

final _adminDistrictsProvider = FutureProvider.autoDispose
    .family<List<({String id, String name})>, String>((
      ref,
      governorateId,
    ) async {
      final gid = governorateId.trim();
      if (gid.length < 32) return const [];
      try {
        final api = ref.read(vewoApiClientProvider);
        final data = await api.getJson(
          'admin_districts',
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

class AdminCompoundsScreen extends ConsumerStatefulWidget {
  const AdminCompoundsScreen({super.key});

  @override
  ConsumerState<AdminCompoundsScreen> createState() =>
      _AdminCompoundsScreenState();
}

class _AdminCompoundsScreenState extends ConsumerState<AdminCompoundsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _visibleItems() {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((c) {
      final gov = (c['governorate']?.toString() ?? '').toLowerCase();
      final dname = (c['district_name']?.toString() ?? '').toLowerCase();
      final name = (c['compound_name']?.toString() ?? '').toLowerCase();
      return gov.contains(q) || dname.contains(q) || name.contains(q);
    }).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson('admin/compounds');
      final raw = data['items'];
      final list = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            list.add(e);
          } else if (e is Map) {
            list.add(Map<String, dynamic>.from(e));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } on VewoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'تعذر التحميل — نفّذ patch_compounds_mysql.sql و patch_follows_packages_engagement_mysql.sql';
        _loading = false;
      });
    }
  }

  Future<void> _upsert({
    String id = '',
    required String governorate,
    required String name,
    required String photoUrl,
    required int sortOrder,
    required bool isActive,
    required String districtId,
    required String districtName,
  }) async {
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/compounds', {
        'action': 'upsert',
        if (id.isNotEmpty) 'id': id,
        'governorate': governorate.trim(),
        'compound_name': name.trim(),
        'photo_url': photoUrl.trim(),
        'sort_order': sortOrder,
        'is_active': isActive ? 1 : 0,
        if (districtId.trim().length >= 32) 'district_id': districtId.trim(),
        if (districtName.trim().isNotEmpty)
          'district_name': districtName.trim(),
      });
      if (!mounted) return;
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المجمع'),
        content: const Text(
          'هل تريد حذف هذا المجمع؟ لا يمكن الحذف إن وُجدت منشورات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.deleteJson('admin/compounds', query: {'id': id});
      if (!mounted) return;
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? initial}) async {
    final initialGov = (initial?['governorate']?.toString() ?? '').trim();
    final initialDistrictId = (initial?['district_id']?.toString() ?? '')
        .trim();
    String? selectedGovId;
    var selectedDistrictId = initialDistrictId.length >= 32
        ? initialDistrictId
        : null;
    final nameCtrl = TextEditingController(
      text: initial?['compound_name']?.toString() ?? '',
    );
    final photoCtrl = TextEditingController(
      text: initial?['photo_url']?.toString() ?? '',
    );
    final sortCtrl = TextEditingController(
      text: initial?['sort_order']?.toString() ?? '0',
    );
    var active = (initial?['is_active'] == 1 || initial?['is_active'] == true);
    final id = initial?['id']?.toString() ?? '';
    final picker = ImagePicker();
    var uploading = false;

    List<({String id, String name})> govs = const [];
    try {
      govs = await ref.read(_adminGovernoratesProvider.future);
    } catch (_) {}
    if (!mounted) return;
    if (initialGov.isNotEmpty) {
      for (final g in govs) {
        if (g.name == initialGov) {
          selectedGovId = g.id;
          break;
        }
      }
    }

    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) {
            return Consumer(
              builder: (context, ref, _) {
                final gid = selectedGovId;
                final distAsync = gid != null && gid.length >= 32
                    ? ref.watch(_adminDistrictsProvider(gid))
                    : null;
                final govVal =
                    selectedGovId != null &&
                        govs.any((g) => g.id == selectedGovId)
                    ? selectedGovId
                    : null;
                final photoUrl = photoCtrl.text.trim();
                return AlertDialog(
                  title: Text(id.isEmpty ? 'مجمع جديد' : 'تعديل مجمع'),
                  content: SingleChildScrollView(
                    child: SizedBox(
                      width: 420,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (govs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'أضف محافظات من إعدادات المحافظات أولاً.',
                                style: TextStyle(
                                  color: Theme.of(ctx).colorScheme.error,
                                ),
                              ),
                            ),
                          DropdownButtonFormField<String>(
                            initialValue: govVal,
                            decoration: const InputDecoration(
                              labelText: 'المحافظة',
                              prefixIcon: Icon(Icons.map_outlined),
                            ),
                            items: govs
                                .map(
                                  (g) => DropdownMenuItem<String>(
                                    value: g.id,
                                    child: Text(g.name),
                                  ),
                                )
                                .toList(),
                            onChanged: govs.isEmpty
                                ? null
                                : (v) => setLocal(() {
                                    selectedGovId = v;
                                    selectedDistrictId = null;
                                  }),
                          ),
                          const SizedBox(height: 10),
                          if (distAsync != null) ...[
                            distAsync.when(
                              loading: () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: LinearProgressIndicator(),
                              ),
                              error: (_, _) => const SizedBox.shrink(),
                              data: (dlist) {
                                if (dlist.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final dVal =
                                    selectedDistrictId != null &&
                                        dlist.any(
                                          (d) => d.id == selectedDistrictId,
                                        )
                                    ? selectedDistrictId
                                    : null;
                                return DropdownButtonFormField<String>(
                                  initialValue: dVal,
                                  decoration: const InputDecoration(
                                    labelText: 'القضاء / الناحية',
                                  ),
                                  items: dlist
                                      .map(
                                        (d) => DropdownMenuItem<String>(
                                          value: d.id,
                                          child: Text(d.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setLocal(() => selectedDistrictId = v),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'اسم المجمع',
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (photoUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 120,
                                width: double.infinity,
                                child: CachedNetworkImage(
                                  imageUrl: photoUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => const Icon(
                                    Icons.image_not_supported_outlined,
                                  ),
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: photoCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'صورة الغلاف',
                                    hintText: 'ارفع أو الصق الرابط',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: 'رفع من المعرض',
                                onPressed: uploading
                                    ? null
                                    : () async {
                                        setLocal(() => uploading = true);
                                        try {
                                          final file = await picker.pickImage(
                                            source: ImageSource.gallery,
                                          );
                                          if (file == null) return;
                                          final data = await ref
                                              .read(vewoApiClientProvider)
                                              .postMultipartFile(
                                                'admin/upload',
                                                'file',
                                                file.path,
                                              );
                                          final url = data['public_url']
                                              ?.toString();
                                          if (url == null || url.isEmpty) {
                                            throw VewoApiException(
                                              'لم يُرجع السيرفر رابط الصورة',
                                            );
                                          }
                                          photoCtrl.text = url;
                                          setLocal(() {});
                                        } on VewoApiException catch (e) {
                                          if (!ctx.mounted) return;
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            SnackBar(content: Text(e.message)),
                                          );
                                        } catch (_) {
                                          if (!ctx.mounted) return;
                                          ScaffoldMessenger.of(
                                            ctx,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('تعذر رفع الصورة'),
                                            ),
                                          );
                                        } finally {
                                          if (ctx.mounted) {
                                            setLocal(() => uploading = false);
                                          }
                                        }
                                      },
                                icon: uploading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.photo_library_outlined),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: sortCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'ترتيب العرض',
                            ),
                          ),
                          SwitchListTile(
                            title: const Text('مفعّل'),
                            value: active,
                            onChanged: (v) => setLocal(() => active = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        if (govs.isEmpty || selectedGovId == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('اختر المحافظة')),
                          );
                          return;
                        }
                        if (nameCtrl.text.trim().length < 2) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('اكتب اسم المجمع')),
                          );
                          return;
                        }
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('حفظ'),
                    ),
                  ],
                );
              },
            );
          },
        ),
      );
      if (save != true || !mounted) return;
      final sort = int.tryParse(sortCtrl.text.trim()) ?? 0;
      var govName = initialGov;
      if (selectedGovId != null) {
        for (final g in govs) {
          if (g.id == selectedGovId) {
            govName = g.name;
            break;
          }
        }
      }
      var districtName = initial?['district_name']?.toString() ?? '';
      if (selectedDistrictId != null && selectedGovId != null) {
        try {
          final dlist = await ref.read(
            _adminDistrictsProvider(selectedGovId!).future,
          );
          for (final d in dlist) {
            if (d.id == selectedDistrictId) {
              districtName = d.name;
              break;
            }
          }
        } catch (_) {}
      }
      await _upsert(
        id: id,
        governorate: govName,
        name: nameCtrl.text,
        photoUrl: photoCtrl.text,
        sortOrder: sort,
        isActive: active,
        districtId: selectedDistrictId ?? '',
        districtName: districtName,
      );
    } finally {
      nameCtrl.dispose();
      photoCtrl.dispose();
      sortCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final rows = _visibleItems();
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'بحث بالمحافظة أو اسم المجمع',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = rows[i];
                    final id = c['id']?.toString() ?? '';
                    final name = c['compound_name']?.toString() ?? '';
                    final gov = c['governorate']?.toString() ?? '';
                    final dname = c['district_name']?.toString().trim() ?? '';
                    final photo = c['photo_url']?.toString() ?? '';
                    final cntRaw = c['property_count'] ?? c['posts_count'];
                    final count = cntRaw is num
                        ? cntRaw.toInt()
                        : int.tryParse(cntRaw?.toString() ?? '0') ?? 0;
                    final followers =
                        (c['follower_count'] is num
                            ? (c['follower_count'] as num).toInt()
                            : int.tryParse('${c['follower_count']}') ?? 0) +
                        (c['synthetic_follower_boost'] is num
                            ? (c['synthetic_follower_boost'] as num).toInt()
                            : int.tryParse(
                                    '${c['synthetic_follower_boost']}',
                                  ) ??
                                  0);
                    final active =
                        c['is_active'] == 1 || c['is_active'] == true;
                    return ListTile(
                      leading: photo.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: CachedNetworkImage(
                                  imageUrl: photo,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => Icon(
                                    Icons.apartment_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ),
                            )
                          : Icon(
                              active
                                  ? Icons.location_city_rounded
                                  : Icons.location_city_outlined,
                            ),
                      title: Text(name.isEmpty ? '—' : name),
                      subtitle: Text(
                        [
                          gov,
                          if (dname.isNotEmpty) dname,
                          'منشورات: $count',
                          '$followers متابع',
                          active ? 'مفعّل' : 'معطّل',
                        ].join(' • '),
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openEditor(initial: c),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: id.isEmpty || count > 0
                                ? null
                                : () => _delete(id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة مجمع'),
            ),
          ),
        ),
      ],
    );
  }
}
