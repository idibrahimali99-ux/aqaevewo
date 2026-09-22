import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

class AdminPostingPackagesScreen extends ConsumerStatefulWidget {
  const AdminPostingPackagesScreen({super.key});

  @override
  ConsumerState<AdminPostingPackagesScreen> createState() =>
      _AdminPostingPackagesScreenState();
}

class _AdminPostingPackagesScreenState
    extends ConsumerState<AdminPostingPackagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(vewoApiClientProvider)
          .getJson('admin/posting-packages');
      final list = _parseMaps(data['items']);
      if (!mounted) return;
      setState(() {
        _packages = list;
        _assignments = _parseMaps(data['assignments']);
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

  List<Map<String, dynamic>> _parseMaps(dynamic raw) {
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
    return list;
  }

  List<Map<String, dynamic>> _packagesForTab() {
    final tab = _tabs.index;
    return _packages.where((p) {
      final a = p['applies_to']?.toString() ?? 'both';
      if (tab == 0) return a == 'office' || a == 'both';
      return a == 'marketer' || a == 'both';
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _loadAssignableUsers() async {
    final data = await ref.read(vewoApiClientProvider).getJson('admin/users');
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
    final isMarketerTab = _tabs.index == 1;
    return list.where((u) {
      final role = u['role']?.toString() ?? '';
      final isMarketer = u['is_marketer'] == 1 || u['is_marketer'] == true;
      if (isMarketerTab) return role == 'office' && isMarketer;
      return role == 'office' && !isMarketer;
    }).toList();
  }

  Map<String, dynamic>? _assignmentFor(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    for (final a in _assignments) {
      if (a['id']?.toString() == userId) return a;
    }
    return null;
  }

  Future<void> _assignPackageToUser() async {
    final users = await _loadAssignableUsers();
    if (!mounted) return;
    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مكتب/مسوّق لتعيين الباقة')),
      );
      return;
    }
    final tabPackages = _packagesForTab();
    String? userId;
    String? packageId;
    var unlimited = false;
    final remCtrl = TextEditingController(text: '10');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setL) => AlertDialog(
          title: Text(
            _tabs.index == 0 ? 'تعيين باقة لمكتب' : 'تعيين باقة لمسوّق',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: _tabs.index == 0 ? 'المكتب' : 'المسوّق',
                  ),
                  items: [
                    for (final u in users)
                      DropdownMenuItem(
                        value: u['id']?.toString(),
                        child: Text(
                          (u['office_name']?.toString().trim().isNotEmpty ==
                                          true
                                      ? u['office_name']
                                      : u['full_name'])
                                  ?.toString() ??
                              '—',
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    setL(() {
                      userId = v;
                      final a = _assignmentFor(v);
                      if (a == null) return;
                      final pid = a['posting_package_id']?.toString();
                      packageId = (pid == null || pid.isEmpty) ? null : pid;
                      unlimited =
                          a['posting_trial_unlimited'] == 1 ||
                          a['posting_trial_unlimited'] == true;
                      remCtrl.text =
                          a['posting_listings_remaining']?.toString() ??
                          remCtrl.text;
                    });
                  },
                ),
                if (userId != null && _assignmentFor(userId) != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _quotaLine(_assignmentFor(userId)!),
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  decoration: const InputDecoration(labelText: 'الباقة'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— بدون باقة —'),
                    ),
                    for (final p in tabPackages)
                      DropdownMenuItem<String?>(
                        value: p['id']?.toString(),
                        child: Text(p['name_ar']?.toString() ?? 'باقة'),
                      ),
                  ],
                  onChanged: (v) => setL(() => packageId = v),
                ),
                SwitchListTile(
                  title: const Text('نشر بلا حدود'),
                  value: unlimited,
                  onChanged: (v) => setL(() => unlimited = v),
                ),
                if (!unlimited)
                  TextField(
                    controller: remCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'متبقي للنشر'),
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
              onPressed: userId == null || userId!.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('تعيين'),
            ),
          ],
        ),
      ),
    );
    final remaining = int.tryParse(remCtrl.text.trim()) ?? 0;
    remCtrl.dispose();
    final selectedUserId = userId;
    if (ok != true ||
        selectedUserId == null ||
        selectedUserId.isEmpty ||
        !mounted) {
      return;
    }
    try {
      final body = <String, dynamic>{
        'user_id': selectedUserId,
        'posting_trial_unlimited': unlimited,
        if (!unlimited) 'posting_listings_remaining': remaining,
      };
      if (packageId != null) body['posting_package_id'] = packageId;
      await ref
          .read(vewoApiClientProvider)
          .postJson('admin/assign-package', body);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تعيين الباقة بنجاح')));
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  List<Map<String, dynamic>> _assigneesOf(Map<String, dynamic> p) {
    final raw = p['assignees'];
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
    return list;
  }

  String _quotaLine(Map<String, dynamic> a) {
    final unlimited =
        a['posting_trial_unlimited'] == 1 ||
        a['posting_trial_unlimited'] == true;
    final remaining = a['posting_listings_remaining'];
    final published = a['published_count'] ?? a['published_approved_count'] ?? 0;
    final reels = a['reels_count'] ?? 0;
    final used = a['used_count'];
    final limit = a['posting_package_limit'];
    final remainingTxt = unlimited ? 'بلا حدود' : 'متبقي ${remaining ?? 0}';
    final usedTxt = unlimited
        ? 'نُشر $published'
        : 'نُشر $published${limit == null ? '' : ' من $limit'}';
    final reelsTxt = 'ريلز $reels';
    final extra = used == null ? '' : ' · مستخدم $used';
    return '$remainingTxt · $usedTxt · $reelsTxt$extra';
  }

  Future<void> _showAssignees(Map<String, dynamic> p) async {
    final assignees = _assigneesOf(p);
    final name = p['name_ar']?.toString() ?? p['name']?.toString() ?? 'باقة';
    final lim = p['listing_limit'] ?? p['listings_limit'];
    final unlimited =
        p['is_unlimited'] == 1 || p['is_unlimited'] == true || lim == null;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  name,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${unlimited ? 'بلا حدود' : '$lim منشور'} · ${assignees.length} معيّن',
                ),
                const SizedBox(height: 12),
                if (assignees.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'لم تُعيَّن هذه الباقة لأي مكتب أو مسوّق بعد.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: assignees.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final a = assignees[i];
                        final kind = a['kind_label']?.toString() ?? '';
                        final expiry =
                            (a['posting_subscription_expires_at']
                                        ?.toString() ??
                                    '')
                                .split(' ')
                                .first;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            a['display_name']?.toString() ??
                                a['office_name']?.toString() ??
                                a['full_name']?.toString() ??
                                '—',
                          ),
                          subtitle: Text(
                            [
                              kind,
                              a['full_name']?.toString() ?? '',
                              a['phone']?.toString() ?? '',
                              _quotaLine(a),
                              if (expiry.isNotEmpty) 'ينتهي $expiry',
                              if (a['office_approved'] != 1 &&
                                  a['office_approved'] != true)
                                'بانتظار الموافقة',
                            ].where((e) => e.toString().trim().isNotEmpty).join(' · '),
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إغلاق'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _upsert(initial: p);
                      },
                      child: const Text('تعديل الباقة'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _upsert({
    Map<String, dynamic>? initial,
    String? forceApplies,
  }) async {
    final id = initial?['id']?.toString() ?? '';
    final nameCtrl = TextEditingController(
      text: initial?['name_ar']?.toString() ?? '',
    );
    final limitCtrl = TextEditingController(
      text: initial?['listing_limit']?.toString() ?? '10',
    );
    var unlimited = initial?['listing_limit'] == null;
    var active = initial?['is_active'] != 0 && initial?['is_active'] != false;
    var applies = forceApplies ?? initial?['applies_to']?.toString() ?? 'both';

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
              if (forceApplies == null)
                DropdownButtonFormField<String>(
                  initialValue: applies,
                  decoration: const InputDecoration(labelText: 'ينطبق على'),
                  items: const [
                    DropdownMenuItem(value: 'office', child: Text('مكاتب')),
                    DropdownMenuItem(value: 'marketer', child: Text('مسوقون')),
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
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    final rows = _packagesForTab();
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'باقات المكاتب'),
            Tab(text: 'باقات المسوقين'),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _tabs.index == 0
                        ? 'اختر مكتباً ثم عيّن له باقة ومتبقي النشر'
                        : 'اختر مسوّقاً ثم عيّن له باقة ومتبقي النشر',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _assignPackageToUser,
                    icon: const Icon(Icons.assignment_ind_outlined),
                    label: Text(
                      _tabs.index == 0
                          ? 'تعيين باقة لمكتب'
                          : 'تعيين باقة لمسوّق',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'إدارة قوالب الباقات',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _upsert(
                  forceApplies: _tabs.index == 0 ? 'office' : 'marketer',
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('باقة'),
              ),
              IconButton(
                tooltip: 'تحديث',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = rows[i];
              final lim = p['listing_limit'] ?? p['listings_limit'];
              final unlimited =
                  p['is_unlimited'] == 1 ||
                  p['is_unlimited'] == true ||
                  lim == null;
              final limTxt = unlimited ? 'بلا حدود' : '$lim منشور';
              final assignees = _assigneesOf(p);
              final count = p['assignees_count'] ?? assignees.length;
              final names = assignees
                  .take(3)
                  .map(
                    (a) =>
                        a['display_name']?.toString() ??
                        a['office_name']?.toString() ??
                        a['full_name']?.toString() ??
                        '',
                  )
                  .where((e) => e.trim().isNotEmpty)
                  .join(' · ');
              return ListTile(
                onTap: () => _showAssignees(p),
                title: Text(
                  p['name_ar']?.toString() ?? p['name']?.toString() ?? '',
                ),
                subtitle: Text(
                  [
                    limTxt,
                    '$count معيّن',
                    if (names.isNotEmpty) names,
                  ].join(' · '),
                ),
                isThreeLine: names.isNotEmpty,
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _upsert(initial: p),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
