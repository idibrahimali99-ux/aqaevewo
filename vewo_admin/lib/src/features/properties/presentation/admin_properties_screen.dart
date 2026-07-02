import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../engagement/admin_engagement_schedule_dialog.dart';
import '../../auth/auth_providers.dart';
import '../../users/presentation/admin_user_profile_screen.dart';

/// منشورات: مراجعة، غير مباع، تم البيع — مع رقم صاحب المنشور للتواصل.
class AdminPropertiesScreen extends ConsumerStatefulWidget {
  const AdminPropertiesScreen({super.key});

  @override
  ConsumerState<AdminPropertiesScreen> createState() =>
      _AdminPropertiesScreenState();
}

class _AdminPropertiesScreenState extends ConsumerState<AdminPropertiesScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  late TabController _tabs;
  final _searchNo = TextEditingController();

  static const _statusByTab = ['pending', 'unsold', 'sold'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchNo.dispose();
    super.dispose();
  }

  void _copyPublicNo(int no) {
    final label = '#$no';
    Clipboard.setData(ClipboardData(text: label));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تم نسخ $label')));
  }

  Future<void> _openEngagementForProperty(
    BuildContext context,
    int publicNo,
  ) async {
    await showAdminEngagementScheduleDialog(
      context: context,
      ref: ref,
      targetKind: 'property',
      publicNo: publicNo,
      title: 'جدولة منشور #$publicNo',
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final st = _statusByTab[_tabs.index];
      final q = _searchNo.text.trim().replaceFirst(RegExp(r'^#+'), '');
      final data = await api.getJson(
        'admin/properties',
        query: {'status': st, if (q.isNotEmpty) 'q': q},
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

  Future<void> _publish(String id) async {
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/properties', {'id': id, 'action': 'approve'});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم نشر العقار')));
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _rejectWithNote(String id) async {
    final noteCtrl = TextEditingController();
    var allowResubmit = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('رفض المنشور'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تظهر الملاحظة للناشر في إشعار الجهاز. اتركها فارغة إن لم ترد.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة قبل الرفض',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('قابل لإعادة النشر بعد التعديل'),
                  subtitle: const Text(
                    'يستطيع المالك تعديل المنشور في التطبيق وإعادة الإرسال إذا كان الخادم يدعم ذلك.',
                  ),
                  value: allowResubmit,
                  onChanged: (v) => setLocal(() => allowResubmit = v),
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
              child: const Text('رفض وإشعار'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/properties', {
        'id': id,
        'action': 'reject',
        'reject_note': noteCtrl.text.trim(),
        'resubmission_allowed': allowResubmit ? 1 : 0,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الرفض وإرسال إشعار للناشر')),
      );
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      noteCtrl.dispose();
    }
  }

  Future<void> _markSoldAdmin(String id) async {
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/properties', {'id': id, 'action': 'mark_sold'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعليم المنشور كـ تم البيع')),
      );
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _enableUrgentSale(String id) async {
    final daysCtrl = TextEditingController(text: '3');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفعيل البيع العاجل'),
        content: TextField(
          controller: daysCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'عدد الأيام',
            hintText: 'مثال: 5',
            prefixIcon: Icon(Icons.timer_outlined),
            helperText: 'يمكن كتابة أي مدة من 1 إلى 365 يوم',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تفعيل'),
          ),
        ],
      ),
    );
    final days = int.tryParse(daysCtrl.text.trim()) ?? 0;
    daysCtrl.dispose();
    if (ok != true || !mounted) return;
    if (days < 1 || days > 365) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب مدة صحيحة بين 1 و 365 يوم')),
      );
      return;
    }
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/properties', {
        'id': id,
        'action': 'urgent_sale',
        'urgent_sale_days': days,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تفعيل البيع العاجل لمدة $days أيام')),
      );
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _cancelUrgentSale(String id) async {
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/properties', {
        'id': id,
        'action': 'cancel_urgent_sale',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إلغاء البيع العاجل')));
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _editProperty(Map<String, dynamic> p) async {
    final id = p['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final title = TextEditingController(text: p['title']?.toString() ?? '');
    final gov = TextEditingController(text: p['governorate']?.toString() ?? '');
    final address = TextEditingController(
      text: p['address_line']?.toString() ?? '',
    );
    final price = TextEditingController(
      text: p['price_iqd']?.toString() ?? '0',
    );
    final area = TextEditingController(text: p['area_sqm']?.toString() ?? '0');
    final desc = TextEditingController(
      text: p['description']?.toString() ?? '',
    );
    var purpose = p['purpose']?.toString() == 'rent' ? 'rent' : 'sale';
    var requiresReview = false;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('تعديل المنشور'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'العنوان'),
                    ),
                    TextField(
                      controller: gov,
                      decoration: const InputDecoration(labelText: 'المحافظة'),
                    ),
                    TextField(
                      controller: address,
                      decoration: const InputDecoration(
                        labelText: 'العنوان التفصيلي',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'sale', label: Text('بيع')),
                        ButtonSegment(value: 'rent', label: Text('إيجار')),
                      ],
                      selected: {purpose},
                      onSelectionChanged: (s) =>
                          setLocal(() => purpose = s.first),
                    ),
                    TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'السعر'),
                    ),
                    TextField(
                      controller: area,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'المساحة'),
                    ),
                    TextField(
                      controller: desc,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(labelText: 'الوصف'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('إرجاع لحالة انتظار بعد التعديل'),
                      subtitle: const Text(
                        'فعّلها إذا كان التعديل يحتاج مراجعة قبل العرض.',
                      ),
                      value: requiresReview,
                      onChanged: (v) => setLocal(() => requiresReview = v),
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
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ التعديل'),
              ),
            ],
          ),
        ),
      );
      if (ok != true || !mounted) return;
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/properties', {
        'id': id,
        'action': 'update',
        'title': title.text.trim(),
        'governorate': gov.text.trim(),
        'address_line': address.text.trim(),
        'purpose': purpose,
        'price_iqd': int.tryParse(price.text.trim()) ?? 0,
        'area_sqm': int.tryParse(area.text.trim()) ?? 0,
        'description': desc.text.trim(),
        'requires_review': requiresReview ? 1 : 0,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ تعديل المنشور')));
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      title.dispose();
      gov.dispose();
      address.dispose();
      price.dispose();
      area.dispose();
      desc.dispose();
    }
  }

  Future<void> _deleteProperty(String id) async {
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المنشور'),
        content: const Text('هل تريد حذف هذا المنشور نهائياً؟'),
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
      await api.deleteJson('admin/properties', query: {'id': id});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف المنشور')));
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String? _sanitizeDetailsJson(String? s) {
    if (s == null) return null;
    var t = s.trim();
    if (t.isEmpty || t == 'null') return null;
    final i = t.indexOf('{');
    if (i > 0) {
      t = t.substring(i);
    }
    return t;
  }

  Map<String, dynamic>? _tryParseJson(String? s) {
    final raw = _sanitizeDetailsJson(s);
    if (raw == null) return null;
    try {
      final o = jsonDecode(raw);
      if (o is Map) return Map<String, dynamic>.from(o);
    } catch (_) {}
    return null;
  }

  (double?, double?) _latLngFromDetails(String? details) {
    final m = _tryParseJson(details);
    if (m == null) return (null, null);
    double? toD(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '');
    }

    final loc = m['location'];
    if (loc is Map) {
      final lm = Map<String, dynamic>.from(loc);
      final lat = toD(lm['lat'] ?? lm['latitude']);
      final lng = toD(lm['lng'] ?? lm['longitude'] ?? lm['lon']);
      if (lat != null && lng != null) {
        return (lat, lng);
      }
    }

    final lat = toD(m['lat'] ?? m['latitude'] ?? m['Lat']);
    final lng = toD(
      m['lng'] ?? m['longitude'] ?? m['Lng'] ?? m['lon'] ?? m['long'],
    );
    return (lat, lng);
  }

  List<Widget> _humanDetailRows(
    BuildContext context,
    Map<String, dynamic> map,
  ) {
    const labels = <String, String>{
      'parcel_listing': 'أرض مقسمة',
      'negotiable': 'قابل للتفاوض',
      'district_name': 'المنطقة / القضاء',
      'parcel_name': 'المقاطعة',
      'compound_name': 'المجمع',
      'segment': 'التصنيف الفرعي',
      'purpose': 'الغرض',
      'category': 'الفئة',
      'notes': 'ملاحظات',
      'floor': 'الطابق',
      'rooms': 'الغرف',
      'bathrooms': 'الحمامات',
      'bedrooms': 'غرف النوم',
      'living_rooms': 'الصالات',
      'kitchens': 'المطابخ',
      'parking': 'موقف سيارات',
      'furnished': 'مفروش',
    };

    String fmt(dynamic v) {
      if (v == null) return '';
      if (v is bool) return v ? 'نعم' : 'لا';
      if (v is Map || v is List) return '';
      return v.toString().trim();
    }

    final rows = <Widget>[];
    final scheme = Theme.of(context).colorScheme;
    map.forEach((key, value) {
      if (!labels.containsKey(key)) return;
      final label = labels[key]!;
      final text = fmt(value);
      if (text.isEmpty) return;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 118,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ),
            ],
          ),
        ),
      );
    });
    return rows;
  }

  List<String> _imageUrlsFor(Map<String, dynamic> p) {
    final raw = p['image_urls_raw']?.toString() ?? '';
    if (raw.isEmpty || raw == 'null') {
      final t = p['thumb_url']?.toString() ?? '';
      return t.isNotEmpty ? [t] : <String>[];
    }
    return raw
        .split('|||')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _videoUrlsFor(Map<String, dynamic> p) {
    final raw =
        p['video_urls_raw']?.toString() ?? p['video_url']?.toString() ?? '';
    if (raw.isEmpty || raw == 'null') return const <String>[];
    return raw
        .split('|||')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _scopeTagsFor(Map<String, dynamic> p) {
    final tags = <String>[];
    final cat = p['category']?.toString() ?? '';
    final seg = p['segment']?.toString() ?? '';
    final details = _tryParseJson(p['details_json']?.toString()) ?? const {};
    String catAr = switch (cat) {
      'land' => 'قسم الأراضي',
      'house' => 'قسم البيوت',
      'apartment' => 'قسم الشقق',
      'shop' => 'قسم المحلات',
      'compound' => 'قسم المجمعات',
      'villa' => 'قسم الفلل',
      _ => cat,
    };
    if (seg == 'parcel') catAr = 'قسم المقاطعات';
    if (catAr.isNotEmpty) tags.add(catAr);
    final compoundName = details['compound_name']?.toString().trim() ?? '';
    final parcelName = details['parcel_name']?.toString().trim() ?? '';
    final districtName = details['district_name']?.toString().trim() ?? '';
    if (compoundName.isNotEmpty) tags.add('المجمع: $compoundName');
    if (parcelName.isNotEmpty) tags.add('المقاطعة: $parcelName');
    if (seg == 'parcel' && districtName.isNotEmpty) {
      tags.add('المنطقة: $districtName');
    }
    return tags;
  }

  Future<void> _openFullReview(Map<String, dynamic> p) async {
    final title = p['title']?.toString() ?? '—';
    final detailsRaw = p['details_json']?.toString();
    final desc = p['description']?.toString() ?? '';
    final imgs = _imageUrlsFor(p);
    final videos = _videoUrlsFor(p);
    final (lat, lng) = _latLngFromDetails(detailsRaw);
    final parsed = _tryParseJson(detailsRaw);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.98,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                if (imgs.isNotEmpty || videos.isNotEmpty)
                  SizedBox(
                    height: 240,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        PageView.builder(
                          itemCount: imgs.length + videos.length,
                          itemBuilder: (c, i) {
                            if (i < videos.length) {
                              return _AdminMediaTile(
                                child: _AdminNetworkVideo(url: videos[i]),
                                onTap: () =>
                                    _openAdminVideoViewer(context, videos[i]),
                              );
                            }
                            final imgIndex = i - videos.length;
                            return _AdminMediaTile(
                              onTap: () => _openAdminImageViewer(
                                context,
                                imgs,
                                imgIndex,
                              ),
                              child: InteractiveViewer(
                                minScale: 0.8,
                                maxScale: 4,
                                child: Image.network(
                                  imgs[imgIndex],
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Center(
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                      ),
                                ),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          bottom: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                '${videos.length} فيديو • ${imgs.length} صورة — اسحب للتنقل',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'لا صور إضافية',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 16),
                if (lat != null && lng != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => _openAdminMapViewer(context, lat, lng),
                      child: SizedBox(
                        height: 220,
                        child: _AdminInlineMap(lat: lat, lng: lng),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    'الإحداثيات: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                ],
                if (desc.isNotEmpty) ...[
                  Text(
                    'الوصف',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    desc,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 12),
                ],
                if (parsed != null && parsed.isNotEmpty) ...[
                  Text(
                    'تفاصيل إضافية',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._humanDetailRows(context, parsed),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _previewThenPublish(Map<String, dynamic> p) async {
    final id = p['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final title = p['title']?.toString() ?? '—';
    final gov = p['governorate']?.toString() ?? '';
    final addr = p['address_line']?.toString() ?? '';
    final cat = p['category']?.toString() ?? '';
    final purpose = p['purpose']?.toString() == 'rent' ? 'إيجار' : 'بيع';
    final price = p['price_iqd']?.toString() ?? '';
    final area = p['area_sqm']?.toString() ?? '';
    final desc = p['description']?.toString() ?? '';
    final imgs = _imageUrlsFor(p);
    final videos = _videoUrlsFor(p);
    final (lat, lng) = _latLngFromDetails(p['details_json']?.toString());
    final scopeTags = _scopeTagsFor(p);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                'معاينة قبل الموافقة',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              _AdminPropertyPreviewCard(
                title: title,
                location: [
                  gov,
                  addr,
                ].where((e) => e.trim().isNotEmpty).join(' • '),
                tags: [
                  ...scopeTags,
                  if (cat.isNotEmpty) cat,
                  purpose,
                  if (area.isNotEmpty) '$area م²',
                ],
                price: price.isEmpty ? 'بدون سعر' : '$price د.ع',
                description: desc,
                imageUrls: imgs,
                videoUrls: videos,
                lat: lat,
                lng: lng,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('رجوع'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.publish_rounded),
                      label: const Text('موافقة ونشر'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await _publish(id);
    }
  }

  Future<void> _callPhone(String raw) async {
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('tel:$digits');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر فتح الاتصال')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر فتح الاتصال')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = _tabs.index;
    final emptyHint = switch (tabIndex) {
      0 => 'لا توجد منشورات بانتظار المراجعة.',
      1 => 'لا توجد عقارات منشورة غير مباعة.',
      _ => 'لا توجد منشورات مُعلَّمة كـ تم البيع.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchNo,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'بحث برقم المنشور (#20000001)',
              prefixIcon: Icon(Icons.tag_rounded),
              isDense: true,
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: TabBar(
            controller: _tabs,
            onTap: (_) => _load(),
            tabs: const [
              Tab(text: 'مراجعة'),
              Tab(text: 'لم يُبع'),
              Tab(text: 'تم البيع'),
            ],
          ),
        ),
        if (_error != null)
          Material(
            color: Theme.of(
              context,
            ).colorScheme.errorContainer.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _load,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading && _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  )
                : _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.12,
                      ),
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        emptyHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p = _items[i];
                      final id = p['id']?.toString() ?? '';
                      final title = p['title']?.toString() ?? '—';
                      final gov = p['governorate']?.toString() ?? '';
                      final addr = p['address_line']?.toString() ?? '';
                      final cat = p['category']?.toString() ?? '';
                      final seg = p['segment']?.toString() ?? '';
                      final purpose = p['purpose']?.toString() ?? '';
                      final price = p['price_iqd']?.toString() ?? '';
                      final area = p['area_sqm']?.toString() ?? '';
                      final desc = p['description']?.toString() ?? '';
                      final thumb = p['thumb_url']?.toString() ?? '';
                      final ownerPhone = p['owner_phone']?.toString() ?? '';
                      final ownerName = p['owner_name']?.toString() ?? '';
                      final officeName = p['office_name']?.toString() ?? '';
                      final ownerId = p['owner_user_id']?.toString() ?? '';
                      final ownerAvatar =
                          p['owner_avatar_url']?.toString().trim() ?? '';
                      final pubRaw = p['property_public_no'];
                      final pubNo = pubRaw is num
                          ? pubRaw.toInt()
                          : int.tryParse(pubRaw?.toString() ?? '');
                      final detailsRaw = p['details_json']?.toString() ?? '';
                      Map<String, dynamic> details = {};
                      if (detailsRaw.isNotEmpty) {
                        try {
                          final decoded = jsonDecode(detailsRaw);
                          if (decoded is Map) {
                            details = Map<String, dynamic>.from(decoded);
                          }
                        } catch (_) {}
                      }
                      final isUrgent = details['urgent_sale'] == true;

                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (pubNo != null && pubNo > 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Material(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _copyPublicNo(pubNo),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.tag_rounded,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'رقم المنشور',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  Text(
                                                    '#$pubNo',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.copy_rounded,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 96,
                                      height: 72,
                                      child: thumb.isNotEmpty
                                          ? Image.network(
                                              thumb,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => ColoredBox(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    child: const Icon(
                                                      Icons.home_work_outlined,
                                                    ),
                                                  ),
                                            )
                                          : ColoredBox(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              child: const Icon(
                                                Icons
                                                    .image_not_supported_outlined,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$gov • $cat • $seg${purpose.isNotEmpty ? ' • $purpose' : ''}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        if (addr.isNotEmpty)
                                          Text(
                                            addr,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.visibility_outlined,
                                              size: 18,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${(p['views'] is num) ? (p['views'] as num).toInt() : int.tryParse('${p['views'] ?? 0}') ?? 0}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const Spacer(),
                                            if (pubNo != null &&
                                                pubNo > 0 &&
                                                ref
                                                    .watch(adminSessionProvider)
                                                    .canAccess('engagement'))
                                              TextButton.icon(
                                                onPressed: () =>
                                                    _openEngagementForProperty(
                                                      context,
                                                      pubNo,
                                                    ),
                                                icon: const Icon(
                                                  Icons.trending_up_rounded,
                                                  size: 18,
                                                ),
                                                label: const Text('جدولة'),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (ownerName.isNotEmpty || ownerId.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Material(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: ownerId.isEmpty
                                          ? null
                                          : () {
                                              Navigator.of(context).push<void>(
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      AdminUserProfileScreen(
                                                        userId: ownerId,
                                                      ),
                                                ),
                                              );
                                            },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundImage:
                                                  ownerAvatar.isNotEmpty
                                                  ? NetworkImage(ownerAvatar)
                                                  : null,
                                              child: ownerAvatar.isEmpty
                                                  ? const Icon(
                                                      Icons.person_outline,
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
                                                    'الناشر',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                  Text(
                                                    ownerName.isNotEmpty
                                                        ? ownerName
                                                        : 'حساب المالك',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                  ),
                                                  if (ownerId.isNotEmpty)
                                                    Text(
                                                      'عرض الملف الشخصي ←',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                          ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_left,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Chip(
                                    avatar: Icon(
                                      Icons.payments_outlined,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    label: Text('السعر: $price د.ع'),
                                  ),
                                  Chip(
                                    avatar: Icon(
                                      Icons.straighten_rounded,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    label: Text('المساحة: $area م²'),
                                  ),
                                  if (ownerPhone.isNotEmpty)
                                    ActionChip(
                                      avatar: const Icon(
                                        Icons.call_outlined,
                                        size: 18,
                                      ),
                                      label: Text(ownerPhone),
                                      onPressed: () => _callPhone(ownerPhone),
                                    ),
                                  if (ownerName.isNotEmpty)
                                    Chip(label: Text('المعلن: $ownerName')),
                                  if (officeName.isNotEmpty)
                                    Chip(label: Text('مكتب: $officeName')),
                                ],
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  desc.length > 220
                                      ? '${desc.substring(0, 220)}…'
                                      : desc,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(height: 1.45),
                                ),
                              ],
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _openFullReview(p),
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('مراجعة كاملة — صور وخريطة'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: id.isEmpty
                                    ? null
                                    : () => _editProperty(p),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('تعديل بيانات المنشور'),
                              ),
                              const SizedBox(height: 12),
                              if (tabIndex == 0)
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: id.isEmpty
                                            ? null
                                            : () => _previewThenPublish(p),
                                        icon: const Icon(Icons.publish_rounded),
                                        label: const Text('معاينة ونشر'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      tooltip: 'حذف',
                                      onPressed: id.isEmpty
                                          ? null
                                          : () => _deleteProperty(id),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: id.isEmpty
                                          ? null
                                          : () => _rejectWithNote(id),
                                      child: const Text('رفض'),
                                    ),
                                  ],
                                )
                              else if (tabIndex == 1)
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton.icon(
                                            onPressed: id.isEmpty
                                                ? null
                                                : () => _markSoldAdmin(id),
                                            icon: const Icon(
                                              Icons.sell_outlined,
                                            ),
                                            label: const Text(
                                              'تعليم كـ تم البيع',
                                            ),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF1565C0,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.filledTonal(
                                          tooltip: 'حذف',
                                          onPressed: id.isEmpty
                                              ? null
                                              : () => _deleteProperty(id),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (isUrgent)
                                      OutlinedButton.icon(
                                        onPressed: id.isEmpty
                                            ? null
                                            : () => _cancelUrgentSale(id),
                                        icon: const Icon(
                                          Icons.local_fire_department_outlined,
                                        ),
                                        label: const Text('إلغاء البيع العاجل'),
                                      )
                                    else
                                      FilledButton.icon(
                                        onPressed: id.isEmpty
                                            ? null
                                            : () => _enableUrgentSale(id),
                                        icon: const Text('🔥'),
                                        label: const Text('تفعيل البيع العاجل'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.deepOrange,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'يُعرض للمتابعة فقط — تم التعليم من التطبيق أو اللوحة.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف',
                                      onPressed: id.isEmpty
                                          ? null
                                          : () => _deleteProperty(id),
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _AdminPropertyPreviewCard extends StatelessWidget {
  const _AdminPropertyPreviewCard({
    required this.title,
    required this.location,
    required this.tags,
    required this.price,
    required this.description,
    required this.imageUrls,
    required this.videoUrls,
    required this.lat,
    required this.lng,
  });

  final String title;
  final String location;
  final List<String> tags;
  final String price;
  final String description;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final double? lat;
  final double? lng;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.52,
            child: imageUrls.isEmpty && videoUrls.isEmpty
                ? ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      size: 42,
                    ),
                  )
                : PageView.builder(
                    itemCount: imageUrls.length + videoUrls.length,
                    itemBuilder: (context, i) {
                      if (i < videoUrls.length) {
                        return _AdminMediaTile(
                          child: _AdminNetworkVideo(url: videoUrls[i]),
                          onTap: () =>
                              _openAdminVideoViewer(context, videoUrls[i]),
                        );
                      }
                      final imgIndex = i - videoUrls.length;
                      return _AdminMediaTile(
                        onTap: () =>
                            _openAdminImageViewer(context, imageUrls, imgIndex),
                        child: Image.network(
                          imageUrls[imgIndex],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              ColoredBox(
                                color: scheme.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final tag in tags) Chip(label: Text(tag))],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (location.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    location,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  price,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(description.trim()),
                ],
                if (lat != null && lng != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => _openAdminMapViewer(context, lat!, lng!),
                      child: SizedBox(
                        height: 180,
                        child: _AdminInlineMap(lat: lat!, lng: lng!),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMediaTile extends StatelessWidget {
  const _AdminMediaTile({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        PositionedDirectional(
          top: 10,
          end: 10,
          child: IconButton.filledTonal(
            tooltip: 'عرض كامل',
            onPressed: onTap,
            icon: const Icon(Icons.open_in_full_rounded),
          ),
        ),
      ],
    );
  }
}

Future<void> _openAdminImageViewer(
  BuildContext context,
  List<String> imageUrls,
  int initialIndex,
) async {
  if (imageUrls.isEmpty) return;
  await showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: _AdminImageViewer(
        imageUrls: imageUrls,
        initialIndex: initialIndex.clamp(0, imageUrls.length - 1),
      ),
    ),
  );
}

class _AdminImageViewer extends StatefulWidget {
  const _AdminImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_AdminImageViewer> createState() => _AdminImageViewerState();
}

class _AdminImageViewerState extends State<_AdminImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.imageUrls.length,
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (context, index) {
            return InteractiveViewer(
              minScale: 0.7,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 56,
                  ),
                ),
              ),
            );
          },
        ),
        SafeArea(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    '${_index + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _openAdminVideoViewer(BuildContext context, String url) async {
  if (url.trim().isEmpty) return;
  await showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: _AdminVideoViewer(url: url),
    ),
  );
}

class _AdminVideoViewer extends StatelessWidget {
  const _AdminVideoViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: _AdminNetworkVideo(url: url, autoplay: true)),
        SafeArea(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: IconButton.filledTonal(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminNetworkVideo extends StatefulWidget {
  const _AdminNetworkVideo({required this.url, this.autoplay = false});

  final String url;
  final bool autoplay;

  @override
  State<_AdminNetworkVideo> createState() => _AdminNetworkVideoState();
}

class _AdminNetworkVideoState extends State<_AdminNetworkVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    final c = VideoPlayerController.networkUrl(uri);
    _controller = c;
    try {
      await c.initialize();
      if (widget.autoplay) await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _controller = null);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !_ready) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          c.value.isPlaying ? c.pause() : c.play();
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
          if (!c.value.isPlaying)
            const Center(
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.black54,
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(c, allowScrubbing: true),
          ),
        ],
      ),
    );
  }
}

Future<void> _openAdminMapViewer(
  BuildContext context,
  double lat,
  double lng,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('موقع العقار'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: _AdminInlineMap(lat: lat, lng: lng),
      ),
    ),
  );
}

class _AdminInlineMap extends StatefulWidget {
  const _AdminInlineMap({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  State<_AdminInlineMap> createState() => _AdminInlineMapState();
}

class _AdminInlineMapState extends State<_AdminInlineMap> {
  BitmapDescriptor? _pinIcon;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final icon = await _adminPropertyPinIcon();
    if (!mounted) return;
    setState(() => _pinIcon = icon);
  }

  @override
  Widget build(BuildContext context) {
    final pos = LatLng(widget.lat, widget.lng);
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: pos, zoom: 16),
      markers: {
        Marker(
          markerId: const MarkerId('property_location'),
          position: pos,
          icon: _pinIcon ?? BitmapDescriptor.defaultMarker,
          infoWindow: const InfoWindow(title: 'موقع العقار'),
        ),
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      compassEnabled: true,
    );
  }
}

Future<BitmapDescriptor> _adminPropertyPinIcon() async {
  const size = 128.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..isAntiAlias = true;
  const gold = Color(0xFFC9A227);
  const dark = Color(0xFF17213B);

  final pinPath = Path()
    ..moveTo(size / 2, size - 10)
    ..cubicTo(size * 0.18, size * 0.66, size * 0.16, size * 0.38, size / 2, 10)
    ..cubicTo(
      size * 0.84,
      size * 0.38,
      size * 0.82,
      size * 0.66,
      size / 2,
      size - 10,
    )
    ..close();

  paint.color = Colors.black.withValues(alpha: 0.20);
  canvas.drawOval(
    Rect.fromCenter(
      center: const Offset(size / 2, size - 8),
      width: 50,
      height: 13,
    ),
    paint,
  );
  paint.color = gold;
  canvas.drawPath(pinPath, paint);
  paint
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5
    ..color = Colors.white;
  canvas.drawPath(pinPath, paint);
  paint
    ..style = PaintingStyle.fill
    ..color = Colors.white;
  canvas.drawCircle(const Offset(size / 2, 47), 23, paint);
  paint.color = dark;
  canvas.drawCircle(const Offset(size / 2, 47), 14, paint);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return BitmapDescriptor.defaultMarker;
  return BitmapDescriptor.bytes(bytes.buffer.asUint8List());
}
