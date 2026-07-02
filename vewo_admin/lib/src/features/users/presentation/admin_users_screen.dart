import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../auth/auth_providers.dart';
import 'admin_user_profile_screen.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  static const _permissionLabels = <String, String>{
    'promotions': 'إعلانات الرئيسية',
    'news': 'أخبار العقارات',
    'offices': 'المكاتب',
    'parcels': 'المقاطعات والمجمعات السكنية',
    'properties': 'المنشورات',
    'reels': 'الريلز',
    'engagement': 'جدولة مشاهدات ولايكات',
    'chats': 'المحادثات',
    'users': 'المستخدمون والمسوقون وباقات النشر',
    'settings': 'الإعدادات والمحافظات والأقضية',
  };

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  late TabController _tabs;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final q = _searchCtrl.text.trim();
      final data = await api.getJson(
        'admin/users',
        query: q.isEmpty ? null : {'q': q},
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
        _error = 'تعذر التحميل';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filteredForTab() {
    final tab = _tabs.index;
    bool keep(Map<String, dynamic> u) {
      final role = u['role']?.toString() ?? '';
      final isMarketer = u['is_marketer'] == 1 || u['is_marketer'] == true;
      if (tab == 0) return role == 'customer';
      if (tab == 1) return role == 'staff' || role == 'admin';
      if (tab == 2) return role == 'office' && !isMarketer;
      if (tab == 3) return role == 'office' && isMarketer;
      return false;
    }

    return _items.where(keep).toList();
  }

  Future<void> _setActive(String userId, bool active) async {
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/users', {
        'user_id': userId,
        'is_active': active ? 1 : 0,
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

  Future<void> _createUser({
    required String role,
    bool isMarketer = false,
  }) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final officeCtrl = TextEditingController();
    final asAdmin = role == 'admin';
    final isStaff = role == 'staff';
    final isOffice = role == 'office';
    final permissions = <String>{'properties', 'chats'};
    final title = switch (role) {
      'customer' => 'إضافة مستخدم شخصي',
      'office' => isMarketer ? 'إضافة مسوّق عقاري' : 'إضافة حساب مكتب',
      'admin' => 'إضافة مسؤول',
      _ => 'إضافة موظف',
    };
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      hintText: '07XXXXXXXXX',
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني (اختياري)',
                      hintText: 'name@email.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  if (isOffice) ...[
                    TextField(
                      controller: officeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم المكتب',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                  TextField(
                    controller: passCtrl,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      helperText: asAdmin ? '8 أحرف على الأقل' : null,
                    ),
                    obscureText: true,
                  ),
                  if (isStaff) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'صلاحيات الموظف',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    for (final entry in _permissionLabels.entries)
                      CheckboxListTile(
                        dense: true,
                        value: permissions.contains(entry.key),
                        title: Text(entry.value),
                        onChanged: (v) => setLocal(() {
                          if (v == true) {
                            permissions.add(entry.key);
                          } else {
                            permissions.remove(entry.key);
                          }
                        }),
                      ),
                  ],
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
                child: const Text('إنشاء'),
              ),
            ],
          ),
        ),
      );
      if (ok != true || !mounted) return;
      try {
        final api = ref.read(vewoApiClientProvider);
        final action = switch (role) {
          'customer' => 'create_customer',
          'office' => 'create_office',
          'admin' => 'create_admin',
          _ => 'create_staff',
        };
        await api.postJson('admin/users', {
          'action': action,
          'full_name': nameCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
          'email': emailCtrl.text.trim(),
          'password': passCtrl.text,
          if (isOffice) 'office_name': officeCtrl.text.trim(),
          if (isOffice && isMarketer) 'is_marketer': 1,
          if (isStaff) 'permissions': permissions.toList(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تم إنشاء الحساب')));
        await _load();
      } on VewoApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      emailCtrl.dispose();
      passCtrl.dispose();
      officeCtrl.dispose();
    }
  }

  Future<void> _toggleOfficeVerified(String userId, bool value) async {
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/offices', {
        'action': 'set_verified',
        'user_id': userId,
        'verified': value ? 1 : 0,
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

  Future<void> _editUser(Map<String, dynamic> u) async {
    final id = u['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final role = u['role']?.toString() ?? '';
    final nameCtrl = TextEditingController(
      text: u['full_name']?.toString() ?? '',
    );
    final officeCtrl = TextEditingController(
      text: u['office_name']?.toString() ?? '',
    );
    final emailCtrl = TextEditingController(text: u['email']?.toString() ?? '');
    final permissions = _parsePermissions(u['staff_permissions_json']);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('تعديل المستخدم'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الظاهر',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      hintText: 'name@email.com',
                    ),
                  ),
                  if (role == 'office') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: officeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم المكتب',
                      ),
                    ),
                  ],
                  if (role == 'staff') ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'صلاحيات الموظف',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    for (final entry in _permissionLabels.entries)
                      CheckboxListTile(
                        dense: true,
                        value: permissions.contains(entry.key),
                        title: Text(entry.value),
                        onChanged: (v) => setLocal(() {
                          if (v == true) {
                            permissions.add(entry.key);
                          } else {
                            permissions.remove(entry.key);
                          }
                        }),
                      ),
                  ],
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
      if (ok != true || !mounted) return;
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/users', {
        'action': 'update_user',
        'user_id': id,
        'full_name': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        if (role == 'office') 'office_name': officeCtrl.text.trim(),
        if (role == 'staff') 'permissions': permissions.toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم التحديث')));
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      nameCtrl.dispose();
      officeCtrl.dispose();
      emailCtrl.dispose();
    }
  }

  String _roleShort(String role) {
    return switch (role) {
      'customer' => 'زبون',
      'office' => 'مكتب',
      'staff' => 'موظف',
      'admin' => 'مشرف',
      _ => role,
    };
  }

  Set<String> _parsePermissions(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toSet();
    final text = raw?.toString() ?? '';
    if (text.isEmpty || text == 'null') return <String>{};
    final out = <String>{};
    for (final key in _permissionLabels.keys) {
      if (text.contains('"$key"') || text.contains(key)) out.add(key);
    }
    return out;
  }

  Future<void> _resetPassword(String userId, String displayName) async {
    final passCtrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('تغيير كلمة مرور $displayName'),
          content: TextField(
            controller: passCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تغيير'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/users', {
        'action': 'reset_password',
        'user_id': userId,
        'password': passCtrl.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور')));
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      passCtrl.dispose();
    }
  }

  Future<void> _confirmPermanentDelete(
    String userId,
    String displayName,
  ) async {
    final pinCtrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('حذف جذري من قاعدة البيانات'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'سيتم حذف «$displayName» وجميع بياناته المرتبطة نهائياً. '
                'أدخل الرمز 1111 للتأكيد.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'رمز التأكيد'),
              ),
            ],
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
              child: const Text('حذف نهائي'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/users', {
        'action': 'delete_user_permanent',
        'user_id': userId,
        'pin': pinCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم الحذف الجذري')));
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      pinCtrl.dispose();
    }
  }

  Future<void> _confirmDeactivate(String userId, String displayName) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المستخدم'),
        content: Text(
          'سيتم تعطيل حساب «$displayName» وحذف جلساته. هل تريد المتابعة؟',
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
    if (go != true || !mounted) return;
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/users', {
        'action': 'delete_user',
        'user_id': userId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تعطيل الحساب')));
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openCreateMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('مستخدم شخصي'),
              onTap: () => Navigator.pop(ctx, 'customer'),
            ),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('مكتب'),
              onTap: () => Navigator.pop(ctx, 'office'),
            ),
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('مسوّق عقاري'),
              subtitle: const Text('نفس صلاحيات المكتب — تسجيل مبسّط'),
              onTap: () => Navigator.pop(ctx, 'marketer'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('موظف لوحة التحكم'),
              onTap: () => Navigator.pop(ctx, 'staff'),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('مسؤول (نفس صلاحيات الأدمن الرئيسي)'),
              onTap: () => Navigator.pop(ctx, 'admin'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'marketer') {
      await _createUser(role: 'office', isMarketer: true);
    } else {
      await _createUser(role: choice);
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

    final session = ref.watch(adminSessionProvider);
    final myId = session.userId ?? '';
    final isSuperAdmin = session.role == 'admin';
    final rows = _filteredForTab();

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو الرقم أو اسم المكتب',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'بحث',
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: _load,
                  ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              child: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'أشخاص'),
                  Tab(text: 'لوحة التحكم'),
                  Tab(text: 'مكاتب'),
                  Tab(text: 'مسوّقون'),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: rows.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.15,
                          ),
                          Icon(
                            Icons.person_search_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'لا نتائج في هذا القسم.',
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          12,
                          8,
                          12,
                          isSuperAdmin ? 96 : 12,
                        ),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 2),
                        itemBuilder: (context, i) {
                          final u = rows[i];
                          final scheme = Theme.of(context).colorScheme;
                          final id = u['id']?.toString() ?? '';
                          final name = u['full_name']?.toString() ?? '—';
                          final phone = u['phone']?.toString() ?? '';
                          final email = u['email']?.toString() ?? '';
                          final role = u['role']?.toString() ?? '';
                          final officeName = u['office_name']?.toString() ?? '';
                          final officeApproved =
                              u['office_approved'] == 1 ||
                              u['office_approved'] == true;
                          final officeVerified =
                              u['office_verified'] == 1 ||
                              u['office_verified'] == true;
                          final isMarketer =
                              u['is_marketer'] == 1 || u['is_marketer'] == true;
                          final active =
                              u['is_active'] == 1 || u['is_active'] == true;
                          final canDeactivate =
                              isSuperAdmin && id.isNotEmpty && id != myId;
                          final canEdit = id.isNotEmpty && id != myId;
                          final profileUrl =
                              u['profile_photo_url']?.toString().trim() ?? '';

                          final titleText =
                              role == 'office' && officeName.isNotEmpty
                              ? officeName
                              : name;
                          final roleLine = [
                            if (role == 'office' && officeName.isNotEmpty)
                              'الممثل: $name',
                            if (role == 'office' && isMarketer) 'مسوّق عقاري',
                            if (role != 'office') _roleShort(role),
                          ].where((e) => e.isNotEmpty).join(' · ');

                          Future<void> openWhatsApp() async {
                            final uri = whatsappUriFromIraqPhone(phone);
                            if (uri == null) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('رقم غير صالح لواتساب'),
                                ),
                              );
                              return;
                            }
                            final ok = await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تعذر فتح التطبيق — انسخ الرقم: $phone',
                                  ),
                                ),
                              );
                            }
                          }

                          return Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: id.isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(context).push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              AdminUserProfileScreen(
                                                userId: id,
                                              ),
                                        ),
                                      );
                                    },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundColor:
                                              scheme.primaryContainer,
                                          backgroundImage: profileUrl.isNotEmpty
                                              ? CachedNetworkImageProvider(
                                                  profileUrl,
                                                )
                                              : null,
                                          child: profileUrl.isEmpty
                                              ? Icon(
                                                  active
                                                      ? Icons.person
                                                      : Icons
                                                            .person_off_outlined,
                                                  color: active
                                                      ? scheme
                                                            .onPrimaryContainer
                                                      : Colors.grey,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                titleText,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 16,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (role == 'office') ...[
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: [
                                                    if (officeVerified)
                                                      Chip(
                                                        avatar: Icon(
                                                          Icons
                                                              .verified_outlined,
                                                          size: 16,
                                                          color: scheme.primary,
                                                        ),
                                                        label: const Text(
                                                          'فيو',
                                                        ),
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                            ),
                                                      ),
                                                    if (officeApproved)
                                                      Chip(
                                                        label: const Text(
                                                          'موافقة',
                                                        ),
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                              if (phone.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                SelectableText(
                                                  phone,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        letterSpacing: 0.2,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ],
                                              if (email.isNotEmpty)
                                                Text(
                                                  email,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              if (roleLine.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 4,
                                                      ),
                                                  child: Text(
                                                    roleLine,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: scheme.outline,
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        if (canEdit)
                                          OutlinedButton.icon(
                                            onPressed: () => _editUser(u),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                            ),
                                            label: const Text('تعديل'),
                                          ),
                                        if (isSuperAdmin && id.isNotEmpty)
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _resetPassword(id, name),
                                            icon: const Icon(
                                              Icons.password_rounded,
                                              size: 18,
                                            ),
                                            label: const Text('كلمة المرور'),
                                          ),
                                        if (role == 'office' &&
                                            officeApproved &&
                                            isSuperAdmin)
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _toggleOfficeVerified(
                                                  id,
                                                  !officeVerified,
                                                ),
                                            icon: Icon(
                                              officeVerified
                                                  ? Icons.verified
                                                  : Icons
                                                        .add_moderator_outlined,
                                              size: 18,
                                            ),
                                            label: Text(
                                              officeVerified
                                                  ? 'إلغاء توثيق'
                                                  : 'توثيق',
                                            ),
                                          ),
                                        if (canDeactivate) ...[
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _confirmDeactivate(id, name),
                                            icon: Icon(
                                              Icons.block_rounded,
                                              size: 18,
                                              color: scheme.error,
                                            ),
                                            label: Text(
                                              'تعطيل',
                                              style: TextStyle(
                                                color: scheme.error,
                                              ),
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _confirmPermanentDelete(
                                                  id,
                                                  titleText,
                                                ),
                                            icon: Icon(
                                              Icons.delete_forever_outlined,
                                              size: 18,
                                              color: scheme.error,
                                            ),
                                            label: Text(
                                              'حذف',
                                              style: TextStyle(
                                                color: scheme.error,
                                              ),
                                            ),
                                          ),
                                        ],
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              active ? 'نشط' : 'معطّل',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelSmall,
                                            ),
                                            const SizedBox(width: 6),
                                            Switch.adaptive(
                                              value: active,
                                              onChanged:
                                                  id.isEmpty || id == myId
                                                  ? null
                                                  : (v) => _setActive(id, v),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (phone.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF25D366,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                        ),
                                        onPressed: openWhatsApp,
                                        icon: const Icon(Icons.chat_rounded),
                                        label: const Text(
                                          'واتساب',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
        if (isSuperAdmin)
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FloatingActionButton.extended(
                onPressed: _openCreateMenu,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('حساب لوحة'),
              ),
            ),
          ),
      ],
    );
  }
}
