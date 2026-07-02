import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

class AdminMarketersScreen extends ConsumerStatefulWidget {
  const AdminMarketersScreen({super.key});

  @override
  ConsumerState<AdminMarketersScreen> createState() => _AdminMarketersScreenState();
}

class _AdminMarketersScreenState extends ConsumerState<AdminMarketersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _marketers = [];
  List<Map<String, dynamic>> _packages = [];

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
      final mData = await api.getJson('admin/marketers');
      final pData = await api.getJson('admin/posting-packages');
      final marketers = <Map<String, dynamic>>[];
      final rawM = mData['items'];
      if (rawM is List) {
        for (final e in rawM) {
          if (e is Map<String, dynamic>) {
            marketers.add(e);
          } else if (e is Map) {
            marketers.add(Map<String, dynamic>.from(e));
          }
        }
      }
      final packages = <Map<String, dynamic>>[];
      final rawP = pData['items'];
      if (rawP is List) {
        for (final e in rawP) {
          if (e is Map<String, dynamic>) {
            packages.add(e);
          } else if (e is Map) {
            packages.add(Map<String, dynamic>.from(e));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _marketers = marketers;
        _packages = packages;
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
        _error = 'تعذر التحميل — نفّذ patch_follows_packages_engagement_mysql.sql';
        _loading = false;
      });
    }
  }

  Future<void> _managePackages() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _PackagesSheet(
        packages: _packages,
        onChanged: _load,
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _editMarketer(Map<String, dynamic> row) async {
    final userId = row['id']?.toString() ?? '';
    if (userId.isEmpty) return;
    final name = row['full_name']?.toString() ?? row['office_name']?.toString() ?? 'مسوق';
    final remCtrl = TextEditingController(
      text: row['posting_listings_remaining']?.toString() ?? '0',
    );
    var unlimited = row['posting_trial_unlimited'] == 1 ||
        row['posting_trial_unlimited'] == true;
    String? packageId = row['posting_package_id']?.toString();
    if (packageId != null && packageId.isEmpty) packageId = null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setL) => AlertDialog(
          title: Text('باقة النشر — $name'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('نشر بلا حدود (تجريبي)'),
                  value: unlimited,
                  onChanged: (v) => setL(() => unlimited = v),
                ),
                if (!unlimited)
                  TextField(
                    controller: remCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'منشورات متبقية',
                    ),
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: packageId != null &&
                          _packages.any((p) => p['id']?.toString() == packageId)
                      ? packageId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'باقة جاهزة',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— بدون باقة —'),
                    ),
                    for (final p in _packages)
                      DropdownMenuItem<String?>(
                        value: p['id']?.toString(),
                        child: Text(p['name_ar']?.toString() ?? 'باقة'),
                      ),
                  ],
                  onChanged: (v) => setL(() => packageId = v),
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
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    final remaining = int.tryParse(remCtrl.text.trim()) ?? 0;
    remCtrl.dispose();
    if (saved != true || !mounted) return;
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/assign-package', {
        'user_id': userId,
        'posting_trial_unlimited': unlimited,
        if (!unlimited) 'posting_listings_remaining': remaining,
        if (packageId != null) 'posting_package_id': packageId,
      });
      if (!mounted) return;
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الباقة')),
      );
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _boostFollowers(Map<String, dynamic> row) async {
    final userId = row['id']?.toString() ?? '';
    if (userId.isEmpty) return;
    final ctrl = TextEditingController(text: '50');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('زيادة متابعين تركيبية'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'العدد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    final add = int.tryParse(ctrl.text.trim()) ?? 0;
    ctrl.dispose();
    if (ok != true || add < 1 || !mounted) return;
    try {
      await ref.read(vewoApiClientProvider).postJson('admin/follow/boost', {
        'target_kind': 'office',
        'target_id': userId,
        'add_count': add,
      });
      if (!mounted) return;
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسوقون وباقات النشر'),
        actions: [
          IconButton(
            tooltip: 'إدارة الباقات',
            onPressed: _loading ? null : _managePackages,
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : _marketers.isEmpty
                  ? const Center(
                      child: Text('لا يوجد مسوقون معتمدون بعد.'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _marketers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final row = _marketers[i];
                        final name = row['full_name']?.toString() ??
                            row['office_name']?.toString() ??
                            '—';
                        final phone = row['phone']?.toString() ?? '';
                        final unlimited = row['posting_trial_unlimited'] == 1 ||
                            row['posting_trial_unlimited'] == true;
                        final rem = row['posting_listings_remaining'];
                        final quota = unlimited
                            ? 'بلا حدود'
                            : 'متبقي: ${rem ?? '—'}';
                        final followers = (row['follower_count'] is num
                                ? (row['follower_count'] as num).toInt()
                                : int.tryParse('${row['follower_count']}') ?? 0) +
                            (row['synthetic_follower_boost'] is num
                                ? (row['synthetic_follower_boost'] as num).toInt()
                                : int.tryParse(
                                      '${row['synthetic_follower_boost']}',
                                    ) ??
                                    0);
                        return ListTile(
                          title: Text(name),
                          subtitle: Text(
                            '$phone · $quota · $followers متابع',
                            textDirection: TextDirection.ltr,
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'pkg') _editMarketer(row);
                              if (v == 'boost') _boostFollowers(row);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'pkg',
                                child: Text('تعديل الباقة / الرصيد'),
                              ),
                              PopupMenuItem(
                                value: 'boost',
                                child: Text('زيادة متابعين'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class _PackagesSheet extends ConsumerStatefulWidget {
  const _PackagesSheet({
    required this.packages,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> packages;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_PackagesSheet> createState() => _PackagesSheetState();
}

class _PackagesSheetState extends ConsumerState<_PackagesSheet> {
  Future<void> _upsert({Map<String, dynamic>? initial}) async {
    final id = initial?['id']?.toString() ?? '';
    final nameCtrl = TextEditingController(
      text: initial?['name_ar']?.toString() ?? '',
    );
    final limitCtrl = TextEditingController(
      text: initial?['listing_limit']?.toString() ?? '10',
    );
    var unlimited = initial?['listing_limit'] == null;
    var active = initial?['is_active'] != 0 && initial?['is_active'] != false;
    var applies = initial?['applies_to']?.toString() ?? 'marketer';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setL) => AlertDialog(
          title: Text(id.isEmpty ? 'باقة جديدة' : 'تعديل باقة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الباقة'),
              ),
              SwitchListTile(
                title: const Text('بلا حدود'),
                value: unlimited,
                onChanged: (v) => setL(() => unlimited = v),
              ),
              if (!unlimited)
                TextField(
                  controller: limitCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'حد المنشورات'),
                ),
              DropdownButtonFormField<String>(
                value: applies,
                decoration: const InputDecoration(labelText: 'ينطبق على'),
                items: const [
                  DropdownMenuItem(value: 'marketer', child: Text('مسوق')),
                  DropdownMenuItem(value: 'office', child: Text('مكتب')),
                  DropdownMenuItem(value: 'both', child: Text('الاثنان')),
                ],
                onChanged: (v) {
                  if (v != null) setL(() => applies = v);
                },
              ),
              SwitchListTile(
                title: const Text('مفعّلة'),
                value: active,
                onChanged: (v) => setL(() => active = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    final limit = int.tryParse(limitCtrl.text.trim()) ?? 0;
    nameCtrl.dispose();
    limitCtrl.dispose();
    if (ok != true) return;
    try {
      await ref.read(vewoApiClientProvider).postJson('admin/posting-packages', {
        if (id.isNotEmpty) 'id': id,
        'name_ar': name,
        if (unlimited) 'unlimited': true,
        if (!unlimited) 'listing_limit': limit,
        'applies_to': applies,
        'is_active': active ? 1 : 0,
      });
      await widget.onChanged();
      if (mounted) setState(() {});
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'باقات النشر',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _upsert(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('باقة'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: widget.packages.length,
              itemBuilder: (context, i) {
                final p = widget.packages[i];
                final lim = p['listing_limit'];
                final limTxt = lim == null ? 'بلا حدود' : '$lim منشور';
                return ListTile(
                  title: Text(p['name_ar']?.toString() ?? ''),
                  subtitle: Text('${p['applies_to']} · $limTxt'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _upsert(initial: p),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
