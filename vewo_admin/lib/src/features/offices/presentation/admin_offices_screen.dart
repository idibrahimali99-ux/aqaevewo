import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

class AdminOfficesScreen extends ConsumerStatefulWidget {
  const AdminOfficesScreen({super.key});

  @override
  ConsumerState<AdminOfficesScreen> createState() => _AdminOfficesScreenState();
}

class _AdminOfficesScreenState extends ConsumerState<AdminOfficesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _approved = [];
  bool _loadingP = true;
  bool _loadingA = true;
  String? _errorP;
  String? _errorA;
  final _search = TextEditingController();
  String _sort = 'created_desc';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) {
        if (_tabs.index == 0) {
          _loadPending();
        } else {
          _loadApproved();
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPending();
      _loadApproved();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    setState(() {
      _loadingP = true;
      _errorP = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson('admin/offices');
      final raw = data['items'];
      final list = _parseList(raw);
      if (!mounted) return;
      setState(() {
        _pending = list;
        _loadingP = false;
      });
    } on VewoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorP = e.message;
        _loadingP = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorP = 'تعذر التحميل';
        _loadingP = false;
      });
    }
  }

  Future<void> _loadApproved() async {
    setState(() {
      _loadingA = true;
      _errorA = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson(
        'admin/offices',
        query: {'scope': 'approved'},
      );
      final raw = data['items'];
      final list = _parseList(raw);
      if (!mounted) return;
      setState(() {
        _approved = list;
        _loadingA = false;
      });
    } on VewoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorA = e.message;
        _loadingA = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorA = 'تعذر التحميل';
        _loadingA = false;
      });
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
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

  List<Map<String, dynamic>> _visible(List<Map<String, dynamic>> source) {
    final q = _search.text.trim().toLowerCase();
    final rows = source.where((u) {
      if (q.isEmpty) return true;
      final name = (u['full_name']?.toString() ?? '').toLowerCase();
      final office = (u['office_name']?.toString() ?? '').toLowerCase();
      final phone = (u['phone']?.toString() ?? '').toLowerCase();
      return name.contains(q) || office.contains(q) || phone.contains(q);
    }).toList();
    rows.sort((a, b) {
      String text(Map<String, dynamic> u) {
        final office = u['office_name']?.toString().trim() ?? '';
        return office.isNotEmpty ? office : (u['full_name']?.toString() ?? '');
      }

      final createdCmp = (b['created_at']?.toString() ?? '').compareTo(
        a['created_at']?.toString() ?? '',
      );
      return switch (_sort) {
        'name_asc' => text(a).compareTo(text(b)),
        'name_desc' => text(b).compareTo(text(a)),
        'phone_asc' => (a['phone']?.toString() ?? '').compareTo(
          b['phone']?.toString() ?? '',
        ),
        _ => createdCmp,
      };
    });
    return rows;
  }

  Future<void> _showOfficeDetailSheet(
    Map<String, dynamic> u, {
    required bool showApprove,
  }) async {
    final id = u['id']?.toString() ?? '';
    final scheme = Theme.of(context).colorScheme;
    final profileUrl = u['profile_photo_url']?.toString().trim() ?? '';
    final officePhoto = u['office_photo_url']?.toString().trim() ?? '';
    final isMarketer =
        u['is_marketer'] == true || u['is_marketer'] == 1 || u['is_marketer'] == '1';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                Text(
                  'بيانات التسجيل',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 16),
                if (profileUrl.isNotEmpty || officePhoto.isNotEmpty)
                  Row(
                    children: [
                      if (profileUrl.isNotEmpty) ...[
                        _PhotoTile(url: profileUrl, label: 'الصورة الشخصية'),
                        const SizedBox(width: 12),
                      ],
                      if (officePhoto.isNotEmpty)
                        _PhotoTile(url: officePhoto, label: 'شعار / مكتب'),
                    ],
                  ),
                if (profileUrl.isNotEmpty || officePhoto.isNotEmpty)
                  const SizedBox(height: 16),
                _detailRow(context, 'اسم صاحب الحساب', u['full_name']?.toString()),
                _detailRow(context, 'الهاتف', u['phone']?.toString()),
                _detailRow(context, 'البريد', u['email']?.toString()),
                _detailRow(context, 'اسم المكتب', u['office_name']?.toString()),
                _detailRow(context, 'عنوان المكتب', u['office_address']?.toString()),
                if (!isMarketer)
                  _detailRow(context, 'رقم الإجازة', u['office_license_no']?.toString()),
                if (isMarketer)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Chip(
                      avatar: Icon(Icons.info_outline, color: scheme.primary),
                      label: const Text('مسوّق عقاري — بدون إجازة إلزامية في النظام'),
                    ),
                  ),
                _detailRow(context, 'تاريخ الطلب', u['created_at']?.toString()),
                const SizedBox(height: 20),
                if (showApprove && id.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _approve(id);
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('الموافقة على المكتب'),
                  ),
                if (!showApprove) ...[
                  Text(
                    'مكتب معتمد — يمكن تغيير التوثيق من تبويب «معتمدون».',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _approve(String userId) async {
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/offices', {'user_id': userId});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تمت الموافقة على المكتب')));
      await _loadPending();
      await _loadApproved();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _setVerified(String userId, bool value) async {
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/offices', {
        'action': 'set_verified',
        'user_id': userId,
        'verified': value ? 1 : 0,
      });
      if (!mounted) return;
      await _loadApproved();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'بحث باسم المكتب أو صاحب الحساب أو الهاتف',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _sort,
                onChanged: (v) => setState(() => _sort = v ?? _sort),
                items: const [
                  DropdownMenuItem(
                    value: 'created_desc',
                    child: Text('الأحدث'),
                  ),
                  DropdownMenuItem(value: 'name_asc', child: Text('الاسم أ-ي')),
                  DropdownMenuItem(
                    value: 'name_desc',
                    child: Text('الاسم ي-أ'),
                  ),
                  DropdownMenuItem(value: 'phone_asc', child: Text('الهاتف')),
                ],
              ),
            ],
          ),
        ),
        Material(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          child: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'بانتظار الموافقة'),
              Tab(text: 'معتمدون وتوثيق'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [_buildPendingTab(), _buildApprovedTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildPendingTab() {
    if (_loadingP) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorP != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorP!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadPending,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    final rows = _visible(_pending);
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'لا توجد مكاتب بانتظار الموافقة.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPending,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final u = rows[i];
          final id = u['id']?.toString() ?? '';
          final name = u['full_name']?.toString() ?? '—';
          final phone = u['phone']?.toString() ?? '';
          final officeName = u['office_name']?.toString().trim() ?? '';
          final addr = u['office_address']?.toString().trim() ?? '';
          final lic = u['office_license_no']?.toString().trim() ?? '';
          final profileUrl = u['profile_photo_url']?.toString().trim() ?? '';
          final officePhoto = u['office_photo_url']?.toString().trim() ?? '';
          final isMarketer =
              u['is_marketer'] == true || u['is_marketer'] == 1 || u['is_marketer'] == '1';
          return Card(
            child: InkWell(
              onTap: () => _showOfficeDetailSheet(u, showApprove: true),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: profileUrl.isNotEmpty
                              ? CachedNetworkImageProvider(profileUrl)
                              : null,
                          child: profileUrl.isEmpty
                              ? const Icon(Icons.storefront_outlined)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                officeName.isNotEmpty ? officeName : name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              Text(name, style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 4),
                              Text(phone),
                              if (addr.isNotEmpty)
                                Text(
                                  addr,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (!isMarketer && lic.isNotEmpty)
                                Text(
                                  'إجازة: $lic',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              if (isMarketer)
                                Chip(
                                  label: const Text('مسوّق عقاري'),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                        ),
                        if (officePhoto.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: officePhoto,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showOfficeDetailSheet(u, showApprove: true),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('مراجعة كاملة'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: id.isEmpty ? null : () => _approve(id),
                          child: const Text('موافقة'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildApprovedTab() {
    if (_loadingA) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorA != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorA!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadApproved,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    final rows = _visible(_approved);
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'لا توجد مكاتب معتمدة.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadApproved,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final u = rows[i];
          final id = u['id']?.toString() ?? '';
          final name = u['full_name']?.toString() ?? '—';
          final phone = u['phone']?.toString() ?? '';
          final on = u['office_name']?.toString().trim() ?? '';
          final verifiedRaw = u['office_verified'];
          final verified =
              verifiedRaw == true || verifiedRaw == 1 || verifiedRaw == '1';
          return Card(
            child: ListTile(
              leading: Icon(
                verified ? Icons.verified_rounded : Icons.storefront_outlined,
                color: verified ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(
                on.isNotEmpty ? on : name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('$phone\n$name', maxLines: 3),
              onTap: id.isEmpty
                  ? null
                  : () => _showOfficeDetailSheet(u, showApprove: false),
              trailing: Switch.adaptive(
                value: verified,
                onChanged:
                    id.isEmpty ? null : (v) => _setVerified(id, v),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty || v == 'null') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: SelectableText(v)),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
