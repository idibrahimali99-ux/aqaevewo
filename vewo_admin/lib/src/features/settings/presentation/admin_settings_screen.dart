import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../auth/auth_providers.dart';

const _homeSectionIconChoices = <({String value, String label, IconData icon})>[
  (value: 'apartment', label: 'عمارة / مكاتب', icon: Icons.apartment_rounded),
  (value: 'building', label: 'بناية', icon: Icons.domain_rounded),
  (value: 'city', label: 'مدينة / مجمع', icon: Icons.location_city_outlined),
  (value: 'grid', label: 'شبكة / مقاطعات', icon: Icons.grid_view_rounded),
  (value: 'home', label: 'بيت', icon: Icons.home_rounded),
  (value: 'key', label: 'مفتاح', icon: Icons.vpn_key_rounded),
  (value: 'land', label: 'أرض / حديقة', icon: Icons.park_outlined),
  (value: 'sale', label: 'للبيع', icon: Icons.sell_rounded),
  (value: 'shop', label: 'محل', icon: Icons.storefront_outlined),
  (value: 'villa', label: 'فيلا', icon: Icons.villa_outlined),
];

IconData _homeSectionAdminIcon(String value) {
  for (final item in _homeSectionIconChoices) {
    if (item.value == value) return item.icon;
  }
  return Icons.widgets_rounded;
}

/// إعدادات تقنية: عنوان الـAPI وفحص الاتصال.
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  String? _health;
  bool _checking = false;

  Future<void> _openBroadcastComposer() async {
    final title = TextEditingController();
    final body = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('رسالة عامة للمستخدمين'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'العنوان (اختياري)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: body,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'الرسالة'),
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
              child: const Text('إرسال'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/broadcast', {
        'title': title.text.trim(),
        'body': body.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إرسال الرسالة')));
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر إرسال الرسالة')));
    } finally {
      title.dispose();
      body.dispose();
    }
  }

  Future<void> _openGovernoratesManager() async {
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
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> saveRow(Map<String, dynamic> row) async {
              final id = row['id']?.toString() ?? '';
              final name = row['name']?.toString() ?? '';
              final active = row['is_active'] == 1 || row['is_active'] == true;
              final sort = (row['sort_order'] is num)
                  ? (row['sort_order'] as num).toInt()
                  : int.tryParse(row['sort_order']?.toString() ?? '0') ?? 0;
              await api.postJson('admin/governorates', {
                'id': id,
                'name': name.trim(),
                'is_active': active ? 1 : 0,
                'sort_order': sort,
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  const ListTile(
                    title: Text(
                      'إدارة المحافظات',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text('تعديل الاسم أو إيقاف الظهور في التطبيق'),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final row = list[i];
                        final nameCtrl = TextEditingController(
                          text: row['name']?.toString() ?? '',
                        );
                        final active =
                            row['is_active'] == 1 || row['is_active'] == true;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          title: TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'الاسم',
                            ),
                            onChanged: (v) => row['name'] = v,
                          ),
                          subtitle: Row(
                            children: [
                              const Text('نشط'),
                              const SizedBox(width: 10),
                              Switch(
                                value: active,
                                onChanged: (v) => setLocal(
                                  () => row['is_active'] = v ? 1 : 0,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            tooltip: 'حفظ',
                            onPressed: () async {
                              try {
                                row['name'] = nameCtrl.text;
                                await saveRow(row);
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('تم الحفظ')),
                                );
                              } catch (_) {
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('تعذر الحفظ')),
                                );
                              } finally {
                                nameCtrl.dispose();
                              }
                            },
                            icon: const Icon(Icons.save_outlined),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر تحميل المحافظات')));
    }
  }

  Future<void> _openHomeSectionsManager() async {
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson('admin/home-sections');
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
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> saveRow(Map<String, dynamic> row) async {
              await api.postJson('admin/home-sections', {
                'section_key': row['section_key']?.toString() ?? '',
                'label': row['label']?.toString() ?? '',
                'icon_name': row['icon_name']?.toString() ?? 'home',
                'route_target': row['route_target']?.toString() ?? '',
                'sort_order':
                    int.tryParse(row['sort_order']?.toString() ?? '0') ?? 0,
                'is_active':
                    (row['is_active'] == true ||
                        row['is_active']?.toString() == '1')
                    ? 1
                    : 0,
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  const ListTile(
                    title: Text(
                      'أيقونات أقسام الرئيسية',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      'اختر الأيقونة التي تظهر لكل قسم في التطبيق الرئيسي',
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final row = list[i];
                        final iconName = row['icon_name']?.toString() ?? 'home';
                        final active =
                            row['is_active'] == 1 || row['is_active'] == true;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            child: Icon(_homeSectionAdminIcon(iconName)),
                          ),
                          title: Text(
                            row['label']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue:
                                    _homeSectionIconChoices.any(
                                      (x) => x.value == iconName,
                                    )
                                    ? iconName
                                    : 'home',
                                decoration: const InputDecoration(
                                  labelText: 'الأيقونة',
                                ),
                                items: [
                                  for (final item in _homeSectionIconChoices)
                                    DropdownMenuItem(
                                      value: item.value,
                                      child: Row(
                                        children: [
                                          Icon(item.icon, size: 18),
                                          const SizedBox(width: 8),
                                          Text(item.label),
                                        ],
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setLocal(
                                  () => row['icon_name'] = v ?? 'home',
                                ),
                              ),
                              Row(
                                children: [
                                  const Text('ظاهر'),
                                  const SizedBox(width: 8),
                                  Switch(
                                    value: active,
                                    onChanged: (v) => setLocal(
                                      () => row['is_active'] = v ? 1 : 0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            tooltip: 'حفظ',
                            onPressed: () async {
                              try {
                                await saveRow(row);
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم حفظ الأيقونة'),
                                  ),
                                );
                              } catch (_) {
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('تعذر الحفظ')),
                                );
                              }
                            },
                            icon: const Icon(Icons.save_outlined),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل أقسام الرئيسية')),
      );
    }
  }

  Future<void> _dangerSystemAction(String action, String successSnack) async {
    final pinCtrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد خطير'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('أدخل الرمز 1111 للمتابعة. لا يمكن التراجع.'),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'رمز التأكيد'),
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تنفيذ'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/system', {
        'pin': pinCtrl.text.trim(),
        'action': action,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successSnack)));
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر تنفيذ الطلب')));
    } finally {
      pinCtrl.dispose();
    }
  }

  Future<void> _checkHealth() async {
    setState(() {
      _checking = true;
      _health = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson('health');
      final ok = data['ok'] == true;
      final db = data['db']?.toString() ?? '';
      if (!mounted) return;
      setState(() {
        _health = ok ? 'متصل — قاعدة: $db' : 'استجابة غير متوقعة';
        _checking = false;
      });
    } on VewoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _health = e.message;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _health = 'تعذر الاتصال';
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(adminSessionProvider);
    final isSuperAdmin = session.role == 'admin';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'إعدادات الربط',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'عنوان الـAPI (VEWO_API_BASE)',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  ApiConfig.baseUrl,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'عند البناء: flutter build apk --dart-define=VEWO_API_BASE=https://نطاقك/api',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'فحص السيرفر',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (_health != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_health!),
                  ),
                FilledButton.icon(
                  onPressed: _checking ? null : _checkHealth,
                  icon: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_done_outlined),
                  label: Text(_checking ? 'جاري الفحص…' : 'اختبار health'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'أدوات الإدارة',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _openBroadcastComposer,
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('إرسال رسالة عامة للمستخدمين'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openGovernoratesManager,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('إدارة المحافظات'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openHomeSectionsManager,
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('أيقونات أقسام الرئيسية'),
                ),
              ],
            ),
          ),
        ),
        if (isSuperAdmin) ...[
          const SizedBox(height: 24),
          Text(
            'منطقة خطرة',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'للمسؤول الرئيسي فقط. يُطلب الرمز 1111 قبل كل إجراء.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Card(
            color: scheme.errorContainer.withValues(alpha: 0.25),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _dangerSystemAction(
                      'maintenance_on',
                      'تم تفعيل وضع الصيانة المؤقتة',
                    ),
                    icon: const Icon(Icons.construction_outlined),
                    label: const Text('إعداد حالة صيانة مؤقتة'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _dangerSystemAction(
                      'maintenance_off',
                      'تم إيقاف وضع الصيانة',
                    ),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('إيقاف الصيانة'),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    onPressed: () => _dangerSystemAction(
                      'delete_all_properties',
                      'تم حذف جميع المنشورات والوسائط ذات الصلة',
                    ),
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('حذف جميع المنشورات'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    onPressed: () => _dangerSystemAction(
                      'delete_all_users_except_me',
                      'تم تصفير المستخدمين والبيانات المرتبطة (ما عدا حسابك)',
                    ),
                    icon: const Icon(Icons.person_off_outlined),
                    label: const Text('حذف جميع المستخدمين'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
