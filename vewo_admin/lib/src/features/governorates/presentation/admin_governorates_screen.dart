import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

class AdminGovernoratesScreen extends ConsumerStatefulWidget {
  const AdminGovernoratesScreen({super.key});

  @override
  ConsumerState<AdminGovernoratesScreen> createState() =>
      _AdminGovernoratesScreenState();
}

class _AdminGovernoratesScreenState extends ConsumerState<AdminGovernoratesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson('admin/governorates');
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

  int _asInt(dynamic v, [int def = 0]) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? def;
  }

  bool _asBool(dynamic v) => v == 1 || v == true || v?.toString() == '1';

  Future<void> _openDistrictsFor(Map<String, dynamic> governorate) async {
    final gid = governorate['id']?.toString() ?? '';
    final gname = governorate['name']?.toString() ?? '';
    if (gid.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => _DistrictsManagerSheet(
        governorateId: gid,
        governorateName: gname,
      ),
    );
  }

  Future<void> _openEditor({Map<String, dynamic>? row}) async {
    final isNew = row == null;
    final id = row?['id']?.toString() ?? '';
    final nameCtrl = TextEditingController(text: row?['name']?.toString() ?? '');
    final sortCtrl = TextEditingController(
      text: row == null ? '' : '${_asInt(row['sort_order'])}',
    );
    var active = isNew ? true : _asBool(row['is_active']);

    try {
      final res = await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(isNew ? 'إضافة محافظة' : 'تعديل محافظة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'اسم المحافظة'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sortCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الترتيب (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                    title: const Text('تفعيل الظهور في التطبيق'),
                  ),
                ],
              ),
            ),
            actions: [
              if (!isNew)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'delete'),
                  child: const Text('حذف'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || res == null || res == 'cancel') return;

      final api = ref.read(vewoApiClientProvider);
      if (res == 'delete') {
        await api.postJson('admin/governorates', {
          'action': 'delete',
          'id': id,
        });
        await _load();
        return;
      }

      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اسم المحافظة مطلوب')),
        );
        return;
      }
      final sort = int.tryParse(sortCtrl.text.trim()) ?? 0;

      if (isNew) {
        await api.postJson('admin/governorates', {
          'action': 'create',
          'name': name,
          'is_active': active ? 1 : 0,
          'sort_order': sort,
        });
      } else {
        await api.postJson('admin/governorates', {
          'id': id,
          'name': name,
          'is_active': active ? 1 : 0,
          'sort_order': sort,
        });
      }
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الحفظ')),
      );
    } finally {
      nameCtrl.dispose();
      sortCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(child: Text(_error!));
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          itemCount: _items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final g = _items[i];
            final name = g['name']?.toString() ?? '';
            final active = _asBool(g['is_active']);
            final sort = _asInt(g['sort_order']);
            return ListTile(
              leading: Icon(
                active ? Icons.check_circle_outline_rounded : Icons.block_outlined,
                color: active ? Colors.green : Theme.of(context).colorScheme.outline,
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('الترتيب: $sort'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'أقضية ونواحي',
                    onPressed: () => _openDistrictsFor(g),
                    icon: const Icon(Icons.location_city_outlined),
                  ),
                  IconButton(
                    tooltip: 'تعديل المحافظة',
                    onPressed: () => _openEditor(row: g),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              onTap: () => _openEditor(row: g),
            );
          },
        ),
      ),
    );
  }
}

class _DistrictsManagerSheet extends ConsumerStatefulWidget {
  const _DistrictsManagerSheet({
    required this.governorateId,
    required this.governorateName,
  });

  final String governorateId;
  final String governorateName;

  @override
  ConsumerState<_DistrictsManagerSheet> createState() =>
      _DistrictsManagerSheetState();
}

class _DistrictsManagerSheetState
    extends ConsumerState<_DistrictsManagerSheet> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson(
        'admin/districts',
        query: {'governorate_id': widget.governorateId},
      );
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
        _error = 'تعذر التحميل — نفّذ patch الأقضية';
        _loading = false;
      });
    }
  }

  int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  bool _asBool(dynamic v) => v == 1 || v == true || v?.toString() == '1';

  String _kindLabel(String? k) => k == 'nahi' ? 'ناحية' : 'قضاء';

  Future<void> _edit({Map<String, dynamic>? row}) async {
    final isNew = row == null;
    final id = row?['id']?.toString() ?? '';
    final nameCtrl = TextEditingController(text: row?['name']?.toString() ?? '');
    final sortCtrl = TextEditingController(
      text: row == null ? '0' : '${_asInt(row['sort_order'])}',
    );
    var active = isNew ? true : _asBool(row['is_active']);
    var kindRaw = row?['kind']?.toString() ?? 'qada';
    if (kindRaw != 'nahi' && kindRaw != 'qada') kindRaw = 'qada';

    try {
      final res = await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(isNew ? 'إضافة قضاء / ناحية' : 'تعديل'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'qada',
                        label: Text('قضاء'),
                        icon: Icon(Icons.account_balance_outlined),
                      ),
                      ButtonSegment<String>(
                        value: 'nahi',
                        label: Text('ناحية'),
                        icon: Icon(Icons.location_on_outlined),
                      ),
                    ],
                    selected: {kindRaw},
                    onSelectionChanged: (s) =>
                        setLocal(() => kindRaw = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sortCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الترتيب'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('نشط'),
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                  ),
                ],
              ),
            ),
            actions: [
              if (!isNew)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'delete'),
                  child: const Text('حذف'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || res == null || res == 'cancel') return;

      final api = ref.read(vewoApiClientProvider);
      if (res == 'delete') {
        await api.postJson('admin/districts', {'action': 'delete', 'id': id});
        await _load();
        return;
      }

      final name = nameCtrl.text.trim();
      if (name.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اسم غير صالح')),
        );
        return;
      }
      final sort = int.tryParse(sortCtrl.text.trim()) ?? 0;

      await api.postJson('admin/districts', {
        if (!isNew) 'id': id,
        'governorate_id': widget.governorateId,
        'name': name,
        'kind': kindRaw,
        'sort_order': sort,
        'is_active': active ? 1 : 0,
      });
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      nameCtrl.dispose();
      sortCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return SizedBox(
      height: h,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'أقضية ونواحي: ${widget.governorateName}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final d = _items[i];
                        final name = d['name']?.toString() ?? '';
                        final active = _asBool(d['is_active']);
                        final kind = d['kind']?.toString();
                        return ListTile(
                          leading: Icon(
                            active ? Icons.place_outlined : Icons.block_outlined,
                          ),
                          title: Text(name),
                          subtitle: Text(
                            '${_kindLabel(kind)} · ترتيب ${_asInt(d['sort_order'])}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _edit(row: d),
                          ),
                          onTap: () => _edit(row: d),
                        );
                      },
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة قضاء أو ناحية'),
            ),
          ),
        ],
      ),
    );
  }
}

