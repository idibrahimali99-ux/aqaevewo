import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../../core/push/admin_fcm_client.dart';
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

  Future<void> _openBroadcastComposer({
    String? presetTitle,
    String? presetBody,
    String kind = 'broadcast',
  }) async {
    final title = TextEditingController(text: presetTitle ?? '');
    final body = TextEditingController(text: presetBody ?? '');
    var target = 'users';
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(kind == 'reminder' ? 'إرسال تذكير فوري' : 'إرسال إشعار فوري'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: target,
                    decoration: const InputDecoration(labelText: 'المستلمين'),
                    items: const [
                      DropdownMenuItem(
                        value: 'users',
                        child: Text('كل مستخدمي التطبيق'),
                      ),
                      DropdownMenuItem(
                        value: 'admins',
                        child: Text('أجهزة الأدمن فقط'),
                      ),
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('الجميع'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setLocal(() => target = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
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
        ),
      );
      if (ok != true || !mounted) return;
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/broadcast', {
        'title': title.text.trim(),
        'body': body.text.trim(),
        'target': target,
        'kind': kind,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
        content: Text(kind == 'reminder' ? 'تم إرسال التذكير' : 'تم إرسال الرسالة'),
      ));
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

  Future<void> _testFcm() async {
    try {
      await ref.read(adminFcmBootstrapProvider).start();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أغلق التطبيق من قائمة التطبيقات الآن وانتظر نحو 40 ثانية دون فتحه. إغلاق خلال 8 ثوانٍ لا يكفي.',
          ),
          duration: Duration(seconds: 8),
        ),
      );
      final api = ref.read(vewoApiClientProvider);
      final data = await api.postJson(
        'admin/fcm/test',
        {'delay_sec': 40},
        timeout: const Duration(seconds: 20),
      );
      if (!mounted) return;
      final mode = data['mode']?.toString() ?? '';
      final queued = data['queued'] == true;
      final sent = data['sent'] ?? data['tokens'];
      final failed = data['failed'];
      final platforms = data['platforms'];
      final hint = data['hint']?.toString();
      final errors = data['errors'];
      final ok = data['ok'] == true;
      final parts = <String>[
        queued
            ? 'تم جدولة الإشعار خلال 40 ثانية — أغلق التطبيق الآن'
            : (ok ? 'FCM أُرسل ($mode)' : 'FCM فشل جزئياً ($mode)'),
        if (!queued) 'نجاح: $sent',
        if (!queued && failed != null) 'فشل: $failed',
        if (platforms is Map) 'منصات: $platforms',
      ];
      if (errors is List && errors.isNotEmpty) {
        parts.add('أخطاء: ${errors.take(3).join(' | ')}');
      }
      if (hint != null && hint.isNotEmpty) {
        parts.add(hint);
      } else if (ok) {
        parts.add('أغلق التطبيق تماماً وتحقق من ظهور الإشعار');
      }
      final msg = parts.join('\n');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: Duration(seconds: ok ? 6 : 12),
        ),
      );
      if (!ok || (hint != null && hint.isNotEmpty)) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ok ? 'تنبيه FCM' : 'تشخيص FCM'),
            content: SingleChildScrollView(child: Text(msg)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر اختبار FCM')),
      );
    }
  }

  Future<void> _openAppUpdateEditor() async {
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson('admin/app-update');
      final androidLatestCtrl = TextEditingController(
        text: data['android_latest_version']?.toString() ??
            data['latest_version']?.toString() ??
            '',
      );
      final androidMinCtrl = TextEditingController(
        text: data['android_min_version']?.toString() ??
            data['min_version']?.toString() ??
            '',
      );
      final androidBuildCtrl = TextEditingController(
        text: '${data['android_min_build'] ?? data['min_build'] ?? 0}',
      );
      final androidCtrl = TextEditingController(
        text: data['android_store_url']?.toString() ?? '',
      );
      final iosLatestCtrl = TextEditingController(
        text: data['ios_latest_version']?.toString() ?? '',
      );
      final iosMinCtrl = TextEditingController(
        text: data['ios_min_version']?.toString() ?? '',
      );
      final iosBuildCtrl = TextEditingController(
        text: '${data['ios_min_build'] ?? 0}',
      );
      final iosCtrl = TextEditingController(
        text: data['ios_store_url']?.toString() ?? '',
      );
      final titleCtrl = TextEditingController(
        text: data['title']?.toString() ?? '',
      );
      final messageCtrl = TextEditingController(
        text: data['message']?.toString() ?? '',
      );
      var androidOn = data['android_enabled']?.toString() == '1' ||
          data['android_enabled'] == true;
      var iosOn =
          data['ios_enabled']?.toString() == '1' || data['ios_enabled'] == true;
      if (!mounted) {
        androidLatestCtrl.dispose();
        androidMinCtrl.dispose();
        androidBuildCtrl.dispose();
        androidCtrl.dispose();
        iosLatestCtrl.dispose();
        iosMinCtrl.dispose();
        iosBuildCtrl.dispose();
        iosCtrl.dispose();
        titleCtrl.dispose();
        messageCtrl.dispose();
        return;
      }
      try {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
              title: const Text('تحديث أندرويد و App Store'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'كل منصة مستقلة: فعّل أندرويد أو App Store على حدة والصق رابط البرنامج.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان التنبيه',
                      ),
                    ),
                    TextField(
                      controller: messageCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'نص التنبيه',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تفعيل تحديث أندرويد'),
                      value: androidOn,
                      onChanged: (v) => setLocal(() => androidOn = v),
                    ),
                    TextField(
                      controller: androidLatestCtrl,
                      decoration: const InputDecoration(
                        labelText: 'إصدار أندرويد',
                        hintText: '1.1.22',
                      ),
                    ),
                    TextField(
                      controller: androidMinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الحد الأدنى لأندرويد',
                      ),
                    ),
                    TextField(
                      controller: androidBuildCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رقم بناء أندرويد',
                      ),
                    ),
                    TextField(
                      controller: androidCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رابط أندرويد (APK أو Google Play)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تفعيل تحديث App Store'),
                      value: iosOn,
                      onChanged: (v) => setLocal(() => iosOn = v),
                    ),
                    TextField(
                      controller: iosLatestCtrl,
                      decoration: const InputDecoration(
                        labelText: 'إصدار App Store',
                        hintText: '1.1.22',
                      ),
                    ),
                    TextField(
                      controller: iosMinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الحد الأدنى لـ App Store',
                      ),
                    ),
                    TextField(
                      controller: iosBuildCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'رقم بناء App Store',
                      ),
                    ),
                    TextField(
                      controller: iosCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رابط App Store',
                        hintText: 'https://apps.apple.com/app/idXXXX',
                      ),
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
                  child: const Text('حفظ المنصتين'),
                ),
              ],
            ),
          ),
        );
        if (ok != true || !mounted) return;
        await api.postJson('admin/app-update', {
          'platform': 'both',
          'title': titleCtrl.text.trim(),
          'message': messageCtrl.text.trim(),
          'android_enabled': androidOn ? 1 : 0,
          'android_latest_version': androidLatestCtrl.text.trim(),
          'android_min_version': androidMinCtrl.text.trim(),
          'android_min_build':
              int.tryParse(androidBuildCtrl.text.trim()) ?? 0,
          'android_store_url': androidCtrl.text.trim(),
          'ios_enabled': iosOn ? 1 : 0,
          'ios_latest_version': iosLatestCtrl.text.trim(),
          'ios_min_version': iosMinCtrl.text.trim(),
          'ios_min_build': int.tryParse(iosBuildCtrl.text.trim()) ?? 0,
          'ios_store_url': iosCtrl.text.trim(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ تحديث أندرويد و App Store')),
        );
      } finally {
        androidLatestCtrl.dispose();
        androidMinCtrl.dispose();
        androidBuildCtrl.dispose();
        androidCtrl.dispose();
        iosLatestCtrl.dispose();
        iosMinCtrl.dispose();
        iosBuildCtrl.dispose();
        iosCtrl.dispose();
        titleCtrl.dispose();
        messageCtrl.dispose();
      }
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل إعدادات التحديث')),
      );
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
                  'عنوان خادم الـAPI',
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
                  label: Text(_checking ? 'جاري الفحص…' : 'فحص الاتصال'),
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
                  label: const Text('إرسال إشعار فوري'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openBroadcastComposer(
                    kind: 'reminder',
                    presetTitle: 'نفتقدك في عقار تاون',
                    presetBody:
                        'تصفّح العقارات الجديدة اليوم ولا تهمل الفرص — افتح التطبيق الآن.',
                  ),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('تذكير: لا تهمل التطبيق'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openBroadcastComposer(
                    kind: 'reminder',
                    presetTitle: 'عقارات جديدة بانتظارك',
                    presetBody:
                        'تم إضافة منشورات جديدة في منطقتك — ادخل وشاهدها قبل أن تفوتك.',
                  ),
                  icon: const Icon(Icons.home_work_outlined),
                  label: const Text('تذكير: عقارات جديدة'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _testFcm,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('اختبار Firebase (FCM)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openAppUpdateEditor,
                  icon: const Icon(Icons.system_update_alt_rounded),
                  label: const Text('تحديث تطبيق عقار تاون'),
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
                      'delete_all_chats',
                      'تم تصفير كل المحادثات من تطبيق المستخدم وتطبيق الأدمن',
                    ),
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text('تصفير جميع المحادثات'),
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
