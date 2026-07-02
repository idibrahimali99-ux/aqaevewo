import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

/// رابط واتساب للعراق (07…) → wa.me/9647…
Uri? whatsappUriFromIraqPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return null;
  var n = digits;
  if (n.startsWith('0')) n = n.substring(1);
  if (n.startsWith('7') && n.length == 10) {
    n = '964$n';
  } else if (!n.startsWith('964')) {
    n = '964$n';
  }
  return Uri.parse('https://wa.me/$n');
}

/// صفحة تعريف مستخدم (زبون / مكتب / موظف) من `GET admin/user?id=`.
class AdminUserProfileScreen extends ConsumerStatefulWidget {
  const AdminUserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<AdminUserProfileScreen> createState() =>
      _AdminUserProfileScreenState();
}

class _AdminUserProfileScreenState extends ConsumerState<AdminUserProfileScreen> {
  Map<String, dynamic>? _user;
  String? _error;
  bool _loading = true;

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
        'admin/user',
        query: {'id': widget.userId},
      );
      final u = data['user'];
      if (!mounted) return;
      setState(() {
        _user = u is Map<String, dynamic>
            ? u
            : u is Map
                ? Map<String, dynamic>.from(u)
                : null;
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

  bool _truthy(dynamic v) =>
      v == true || v == 1 || v?.toString() == '1';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('ملف المستخدم')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('ملف المستخدم')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
              ],
            ),
          ),
        ),
      );
    }
    final u = _user ?? {};
    final role = u['role']?.toString() ?? '';
    final photo = u['profile_photo_url']?.toString().trim() ?? '';
    final officePhoto = u['office_photo_url']?.toString().trim() ?? '';
    final phoneRaw = u['phone']?.toString().trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('ملف المستخدم')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              elevation: 0,
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: scheme.primaryContainer,
                      backgroundImage: photo.isNotEmpty
                          ? CachedNetworkImageProvider(photo)
                          : null,
                      child: photo.isEmpty
                          ? Icon(Icons.person_rounded,
                              size: 52, color: scheme.primary)
                          : null,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      u['full_name']?.toString() ?? '—',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (role == 'office') ...[
                      const SizedBox(height: 6),
                      Text(
                        u['office_name']?.toString().trim().isNotEmpty == true
                            ? u['office_name'].toString().trim()
                            : 'حساب مكتب',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(_roleLabel(role))),
                        if (_truthy(u['is_marketer']))
                          Chip(
                            avatar: Icon(Icons.campaign_outlined,
                                size: 18, color: scheme.primary),
                            label: const Text('مسوّق عقاري'),
                          ),
                        if (role == 'office' && _truthy(u['office_verified']))
                          Chip(
                            avatar: Icon(Icons.verified_rounded,
                                size: 18, color: scheme.primary),
                            label: const Text('موثّق'),
                          ),
                      ],
                    ),
                    if (phoneRaw.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'رقم الهاتف',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  phoneRaw,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'اتصال',
                            onPressed: () async {
                              final uri = Uri(scheme: 'tel', path: phoneRaw);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                            icon: const Icon(Icons.call_rounded),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filled(
                            tooltip: 'واتساب',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              final wa = whatsappUriFromIraqPhone(phoneRaw);
                              if (wa != null && await canLaunchUrl(wa)) {
                                await launchUrl(wa,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.chat_rounded),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'التواصل والحساب',
              children: [
                _kv('المعرّف', u['id']?.toString()),
                _kv('البريد', u['email']?.toString()),
                _kv('نشط', _truthy(u['is_active']) ? 'نعم' : 'لا'),
                _kv('تاريخ الإنشاء', u['created_at']?.toString()),
              ],
            ),
            if (role == 'office') ...[
              const SizedBox(height: 12),
              _SectionCard(
                title: 'المكتب',
                children: [
                  _kv('اسم المكتب', u['office_name']?.toString()),
                  _kv('العنوان', u['office_address']?.toString()),
                  _kv('رقم الإجازة', u['office_license_no']?.toString()),
                  _kv('موافقة التسجيل', _truthy(u['office_approved']) ? 'نعم' : 'لا'),
                  if (officePhoto.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: CachedNetworkImage(
                          imageUrl: officePhoto,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (role == 'staff' || role == 'admin')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _SectionCard(
                  title: 'صلاحيات',
                  children: [
                    SelectableText(
                      u['staff_permissions_json']?.toString() ?? '—',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String r) => switch (r) {
        'customer' => 'زبون',
        'office' => 'مكتب',
        'staff' => 'موظف لوحة',
        'admin' => 'مسؤول',
        _ => r.isEmpty ? '—' : r,
      };

  Widget _kv(String label, String? value) {
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
