import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          if (id.length >= 32 && name.isNotEmpty) out.add((id: id, name: name));
        } else if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final id = m['id']?.toString().trim() ?? '';
          final name = m['name']?.toString().trim() ?? '';
          if (id.length >= 32 && name.isNotEmpty) out.add((id: id, name: name));
        }
      }
    }
    if (out.isNotEmpty) return out;
  } catch (_) {}
  return const [];
});

final _adminDistrictsProvider = FutureProvider.autoDispose
    .family<List<({String id, String name})>, String>((ref, governorateId) async {
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
          if (id.length >= 32 && name.isNotEmpty) out.add((id: id, name: name));
        } else if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final id = m['id']?.toString().trim() ?? '';
          final name = m['name']?.toString().trim() ?? '';
          if (id.length >= 32 && name.isNotEmpty) out.add((id: id, name: name));
        }
      }
    }
    return out;
  } catch (_) {
    return const [];
  }
});

class AdminParcelsScreen extends ConsumerStatefulWidget {
  const AdminParcelsScreen({super.key});

  @override
  ConsumerState<AdminParcelsScreen> createState() => _AdminParcelsScreenState();
}

class _AdminParcelsScreenState extends ConsumerState<AdminParcelsScreen> {
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
    return _items.where((p) {
      final gov = (p['governorate']?.toString() ?? '').toLowerCase();
      final dname = (p['district_name']?.toString() ?? '').toLowerCase();
      final name = (p['parcel_name']?.toString() ?? '').toLowerCase();
      final no = (p['parcel_no']?.toString() ?? '').toLowerCase();
      return gov.contains(q) ||
          dname.contains(q) ||
          name.contains(q) ||
          no.contains(q);
    }).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson('admin_parcels');
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
        _error = 'تعذر التحميل';
        _loading = false;
      });
    }
  }

  Future<void> _upsert({
    String id = '',
    required String governorate,
    required String name,
    required String no,
    required int sortOrder,
    required bool isActive,
    required String districtId,
  }) async {
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin_parcels', {
        'action': 'upsert',
        if (id.isNotEmpty) 'id': id,
        'governorate': governorate.trim(),
        'parcel_name': name.trim(),
        'parcel_no': no.trim(),
        'sort_order': sortOrder,
        'is_active': isActive ? 1 : 0,
        if (districtId.trim().length >= 32) 'district_id': districtId.trim(),
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
        title: const Text('حذف المقاطعة'),
        content: const Text('هل تريد حذف هذه المقاطعة؟'),
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
      await api.deleteJson('admin_parcels', query: {'id': id});
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
    final initialDistrictId =
        (initial?['district_id']?.toString() ?? '').trim();
    String? selectedGovId;
    var selectedDistrictId =
        initialDistrictId.length >= 32 ? initialDistrictId : null;
    final nameCtrl = TextEditingController(
      text: initial?['parcel_name']?.toString() ?? '',
    );
    final noCtrl = TextEditingController(
      text: initial?['parcel_no']?.toString() ?? '',
    );
    final sortCtrl = TextEditingController(
      text: initial?['sort_order']?.toString() ?? '0',
    );
    var active = (initial?['is_active'] == 1 || initial?['is_active'] == true);
    final id = initial?['id']?.toString() ?? '';

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
                final govVal = selectedGovId != null &&
                        govs.any((g) => g.id == selectedGovId)
                    ? selectedGovId
                    : null;
                return AlertDialog(
                  title: Text(id.isEmpty ? 'إضافة مقاطعة' : 'تعديل مقاطعة'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (govs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'لا توجد محافظات في النظام — أضف محافظات من إعدادات المحافظات أولاً.',
                              style: TextStyle(
                                color: Theme.of(ctx).colorScheme.error,
                              ),
                            ),
                          ),
                        DropdownButtonFormField<String>(
                          value: govVal,
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
                            error: (_, __) => const SizedBox.shrink(),
                            data: (dlist) {
                              if (dlist.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'لا توجد أقضية لهذه المحافظة — أضف قضاءً من إعدادات المحافظات.',
                                    style: TextStyle(
                                      color: Theme.of(ctx).colorScheme.error,
                                    ),
                                  ),
                                );
                              }
                              final dVal = selectedDistrictId != null &&
                                      dlist.any((d) => d.id == selectedDistrictId)
                                  ? selectedDistrictId
                                  : null;
                              return DropdownButtonFormField<String>(
                                value: dVal,
                                decoration: const InputDecoration(
                                  labelText: 'القضاء أو الناحية',
                                  prefixIcon:
                                      Icon(Icons.account_balance_outlined),
                                ),
                                items: dlist
                                    .map(
                                      (d) => DropdownMenuItem<String>(
                                        value: d.id,
                                        child: Text(
                                          d.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
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
                            labelText: 'اسم المقاطعة',
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: noCtrl,
                          decoration: const InputDecoration(
                            labelText: 'رقم المقاطعة (اختياري)',
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: sortCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'ترتيب العرض'),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: const Text('مفعلة'),
                          value: active,
                          onChanged: (v) => setLocal(() => active = v),
                        ),
                      ],
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
                        try {
                          final dlist = await ref.read(
                            _adminDistrictsProvider(selectedGovId!).future,
                          );
                          if (dlist.isNotEmpty &&
                              (selectedDistrictId == null ||
                                  selectedDistrictId!.trim().length < 32)) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('اختر القضاء أو الناحية'),
                              ),
                            );
                            return;
                          }
                        } catch (_) {}
                        if (nameCtrl.text.trim().isEmpty) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('اكتب اسم المقاطعة'),
                            ),
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
      await _upsert(
        id: id,
        governorate: govName,
        name: nameCtrl.text,
        no: noCtrl.text,
        sortOrder: sort,
        isActive: active,
        districtId: selectedDistrictId ?? '',
      );
    } finally {
      nameCtrl.dispose();
      noCtrl.dispose();
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
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'بحث بالمحافظة أو اسم/رقم المقاطعة',
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
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = rows[i];
                    final id = p['id']?.toString() ?? '';
                    final gov = p['governorate']?.toString() ?? '';
                    final dname = p['district_name']?.toString().trim() ?? '';
                    final name = p['parcel_name']?.toString() ?? '';
                    final no = p['parcel_no']?.toString() ?? '';
                    final countRaw = p['property_count'];
                    final propertyCount = countRaw is num
                        ? countRaw.toInt()
                        : int.tryParse(countRaw?.toString() ?? '0') ?? 0;
                    final active =
                        p['is_active'] == 1 || p['is_active'] == true;
                    return ListTile(
                      leading: Icon(
                        active
                            ? Icons.grid_view_rounded
                            : Icons.grid_off_rounded,
                      ),
                      title: Text(name.isEmpty ? '—' : name),
                      subtitle: Text(
                        [
                          gov,
                          if (dname.isNotEmpty) dname,
                          if (no.isNotEmpty) 'رقم: $no',
                          if (propertyCount > 0) 'منشورات: $propertyCount',
                        ].join(' • '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'تعديل',
                            onPressed: () => _openEditor(initial: p),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: propertyCount > 0
                                ? 'لا يمكن حذف مقاطعة تحتوي منشورات'
                                : 'حذف',
                            onPressed: id.isEmpty || propertyCount > 0
                                ? null
                                : () => _delete(id),
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
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
              label: const Text('إضافة مقاطعة'),
            ),
          ),
        ),
      ],
    );
  }
}
