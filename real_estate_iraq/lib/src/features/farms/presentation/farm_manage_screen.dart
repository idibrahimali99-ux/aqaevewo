import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/app_responsive.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

class FarmManageScreen extends ConsumerStatefulWidget {
  const FarmManageScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<FarmManageScreen> createState() => _FarmManageScreenState();
}

class _FarmManageScreenState extends ConsumerState<FarmManageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic> _farm = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final start = widget.initialTab.clamp(0, 3).toInt();
    _tabs = TabController(length: 4, vsync: this, initialIndex: start);
    _load();
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
      final data = await ref.read(vewoApiClientProvider).getJson('farms/mine');
      final item = data['item'];
      if (!mounted) return;
      setState(() {
        _farm = item is Map ? Map<String, dynamic>.from(item) : {};
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
        _error = 'تعذر تحميل إعدادات المزرعة';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _maps(String key) {
    final raw = _farm[key];
    if (raw is! List) return [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  Future<void> _toast(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ')),
      );
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الشفتات والخدمات'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'الشفتات'),
            Tab(text: 'الخدمات'),
            Tab(text: 'إعدادات الدفع'),
            Tab(text: 'الصور'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : TabBarView(
              controller: _tabs,
              children: [
                _ShiftsTab(
                  shifts: _maps('shifts'),
                  onSave: (body) => _toast(
                    () => ref.read(vewoApiClientProvider).postJson('farms/shifts', body),
                  ),
                ),
                _ServicesTab(
                  services: _maps('services'),
                  catalog: _maps('amenity_catalog'),
                  selected: [
                    for (final a in (_farm['amenities'] as List? ?? []))
                      a.toString(),
                  ],
                  onService: (body) => _toast(
                    () => ref.read(vewoApiClientProvider).postJson('farms/services', body),
                  ),
                  onAmenities: (ids) => _toast(
                    () => ref.read(vewoApiClientProvider).postJson('farms/save', {
                      'amenities': ids,
                    }),
                  ),
                ),
                _PaymentTab(
                  farm: _farm,
                  onSave: (body) => _toast(
                    () => ref.read(vewoApiClientProvider).postJson('farms/payment-settings', body),
                  ),
                ),
                _PhotosTab(
                  farm: _farm,
                  upload: (bytes, name) async {
                    final up = await ref.read(vewoApiClientProvider).postMultipartBytes('farms/upload', 'file', bytes, name);
                    return up['public_url']?.toString() ?? up['url']?.toString() ?? '';
                  },
                  onSave: (urls) => _toast(
                    () => ref.read(vewoApiClientProvider).postJson('farms/save', {
                      'images': urls,
                      if (urls.isNotEmpty) 'cover_url': urls.first,
                    }),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ShiftsTab extends StatefulWidget {
  const _ShiftsTab({required this.shifts, required this.onSave});

  final List<Map<String, dynamic>> shifts;
  final Future<void> Function(Map<String, dynamic> body) onSave;

  @override
  State<_ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends State<_ShiftsTab> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 16, minute: 0);
  final Set<int> _days = {0, 1, 2, 3, 4, 5, 6};
  DateTime? _specific;
  bool _busy = false;

  static const _dayLabels = ['أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  String _hhmm(TimeOfDay t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.trim()) ?? -1;
    if (name.length < 2 || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب اسم الشفت والسعر')),
      );
      return;
    }
    if (_specific == null && _days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر أيام الشفت أو تاريخاً واحداً')),
      );
      return;
    }
    setState(() => _busy = true);
    final date = _specific;
    await widget.onSave({
      'action': 'upsert',
      'name': name,
      'start_time': _hhmm(_start),
      'end_time': _hhmm(_end),
      'base_price_iqd': price,
      'available_days': date == null ? _days.toList() : <int>[],
      'specific_date': date == null
          ? ''
          : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'is_active': 1,
    });
    if (mounted) {
      _name.clear();
      _price.clear();
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppResponsive.pagePadding(context, accountForShellNav: true),
      children: [
        const Text('الشفت المتاح يظهر للزبون في يومه فقط. اترك التاريخ فارغاً ليتكرر أسبوعياً، أو حدّد يوماً واحداً.'),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'اسم الشفت', hintText: 'مسائي'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: () => _pickTime(true), child: Text('من ${_start.format(context)}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => _pickTime(false), child: Text('إلى ${_end.format(context)}'))),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'السعر بالدينار'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (var i = 0; i < _dayLabels.length; i++)
              FilterChip(
                label: Text(_dayLabels[i]),
                selected: _specific == null && _days.contains(i),
                onSelected: _specific != null
                    ? null
                    : (on) => setState(() {
                        if (on) {
                          _days.add(i);
                        } else {
                          _days.remove(i);
                        }
                      }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            if (_specific != null) {
              setState(() => _specific = null);
              return;
            }
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDate: DateTime.now(),
            );
            if (picked != null) setState(() => _specific = picked);
          },
          icon: const Icon(Icons.event),
          label: Text(_specific == null
              ? 'أو تاريخ واحد فقط'
              : 'تاريخ واحد: ${_specific!.year}-${_specific!.month}-${_specific!.day} — إلغاء'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _add,
          child: const Text('إضافة الشفت'),
        ),
        const SizedBox(height: 20),
        if (widget.shifts.isEmpty)
          const Text('لا توجد شفتات بعد. الشفتات الافتراضية تُنشأ مع الحساب إن لم تُحذف.')
        else
          ...widget.shifts.map((s) {
            final active = s['is_active'] == 1 || s['is_active'] == true;
            final specific = s['specific_date']?.toString() ?? '';
            final days = s['available_days'];
            final dayText = specific.isNotEmpty
                ? specific
                : (days is List && days.isNotEmpty
                    ? days.map((d) => _dayLabels[(int.tryParse('$d') ?? 0).clamp(0, 6)]).join(' · ')
                    : 'كل الأسبوع');
            return Card(
              child: ListTile(
                title: Text('${s['name'] ?? 'شفت'} · ${s['base_price_iqd'] ?? 0} د.ع'),
                subtitle: Text('${s['start_time_12'] ?? s['start_time']} → ${s['end_time_12'] ?? s['end_time']}\n$dayText${active ? '' : ' · متوقف'}'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: active ? 'إيقاف' : 'تفعيل',
                      onPressed: () => widget.onSave({
                        'id': s['id'],
                        'name': s['name'],
                        'start_time': s['start_time'],
                        'end_time': s['end_time'],
                        'base_price_iqd': s['base_price_iqd'],
                        'available_days': days is List ? days : [0, 1, 2, 3, 4, 5, 6],
                        'specific_date': specific,
                        'is_active': active ? 0 : 1,
                      }),
                      icon: Icon(active ? Icons.pause_circle_outline : Icons.play_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () => widget.onSave({'action': 'delete', 'id': s['id']}),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _ServicesTab extends StatefulWidget {
  const _ServicesTab({
    required this.services,
    required this.catalog,
    required this.selected,
    required this.onService,
    required this.onAmenities,
  });

  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> catalog;
  final List<String> selected;
  final Future<void> Function(Map<String, dynamic> body) onService;
  final Future<void> Function(List<String> ids) onAmenities;

  @override
  State<_ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<_ServicesTab> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  late Set<String> _amenities;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _amenities = widget.selected.toSet();
  }

  @override
  void didUpdateWidget(covariant _ServicesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _amenities = widget.selected.toSet();
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppResponsive.pagePadding(context, accountForShellNav: true),
      children: [
        Text('خدمات بسعر', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('تظهر للحاجز ويمكنه إضافتها على سعر الشفت، مثل مشغل أو تنظيف.'),
        const SizedBox(height: 8),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم الخدمة')),
        const SizedBox(height: 8),
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'السعر بالدينار'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final name = _name.text.trim();
                  final price = int.tryParse(_price.text.trim()) ?? -1;
                  if (name.isEmpty || price < 0) return;
                  setState(() => _busy = true);
                  await widget.onService({
                    'action': 'upsert',
                    'name': name,
                    'price_iqd': price,
                    'is_active': 1,
                  });
                  if (mounted) {
                    _name.clear();
                    _price.clear();
                    setState(() => _busy = false);
                  }
                },
          child: const Text('إضافة الخدمة'),
        ),
        const SizedBox(height: 8),
        if (widget.services.isEmpty)
          const Text('لا توجد خدمات إضافية.')
        else
          ...widget.services.map((s) {
            final active = s['is_active'] == 1 || s['is_active'] == true;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${s['name'] ?? ''} · ${s['price_iqd'] ?? 0} د.ع'),
              subtitle: Text(active ? 'ظاهرة للحاجز' : 'مخفية'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => widget.onService({
                      'id': s['id'],
                      'name': s['name'],
                      'price_iqd': s['price_iqd'],
                      'is_active': active ? 0 : 1,
                    }),
                    icon: Icon(active ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  ),
                  IconButton(
                    onPressed: () => widget.onService({'action': 'delete', 'id': s['id']}),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 20),
        Text('ما يتوفر في المزرعة', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('هذه المرافق تظهر في صفحة المزرعة بدون سعر.'),
        const SizedBox(height: 8),
        for (final group in widget.catalog) ...[
          const SizedBox(height: 8),
          Text('${group['emoji'] ?? ''} ${group['label'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
          Wrap(
            spacing: 6,
            children: [
              for (final item in (group['items'] as List? ?? []))
                if (item is Map)
                  FilterChip(
                    label: Text('${item['label'] ?? ''}'),
                    selected: _amenities.contains('${item['id']}'),
                    onSelected: (on) {
                      final id = '${item['id']}';
                      setState(() {
                        if (on) {
                          _amenities.add(id);
                        } else {
                          _amenities.remove(id);
                        }
                      });
                    },
                  ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => widget.onAmenities(_amenities.toList()),
          child: const Text('حفظ المرافق'),
        ),
      ],
    );
  }
}

class _PaymentTab extends StatefulWidget {
  const _PaymentTab({required this.farm, required this.onSave});

  final Map<String, dynamic> farm;
  final Future<void> Function(Map<String, dynamic> body) onSave;

  @override
  State<_PaymentTab> createState() => _PaymentTabState();
}

class _PaymentTabState extends State<_PaymentTab> {
  late final TextEditingController _deposit;
  late final TextEditingController _superqi;
  late bool _depositOn;
  late bool _fullOn;
  late bool _arrivalOn;

  @override
  void initState() {
    super.initState();
    _deposit = TextEditingController(text: '${widget.farm['deposit_iqd'] ?? 0}');
    _superqi = TextEditingController(text: widget.farm['superqi_number']?.toString() ?? '');
    bool on(String key) => widget.farm[key] == 1 || widget.farm[key] == true;
    _depositOn = on('allow_deposit');
    _fullOn = on('allow_full_payment');
    _arrivalOn = on('allow_pay_on_arrival');
  }

  @override
  void dispose() {
    _deposit.dispose();
    _superqi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppResponsive.pagePadding(context, accountForShellNav: true),
      children: [
        const Text('مبلغ العربون ومبلغ الشفت الكامل يحددهما صاحب المزرعة. سعر الشفت هو المبلغ الكامل.'),
        const SizedBox(height: 12),
        TextField(
          controller: _deposit,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'مبلغ العربون (د.ع)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _superqi,
          decoration: const InputDecoration(labelText: 'رقم حساب سوبر كي'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('السماح بالعربون'),
          value: _depositOn,
          onChanged: (v) => setState(() => _depositOn = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('السماح بالدفع الكامل'),
          value: _fullOn,
          onChanged: (v) => setState(() => _fullOn = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('الدفع عند الوصول'),
          value: _arrivalOn,
          onChanged: (v) => setState(() => _arrivalOn = v),
        ),
        FilledButton(
          onPressed: () => widget.onSave({
            'deposit_iqd': int.tryParse(_deposit.text.trim()) ?? 0,
            'superqi_number': _superqi.text.trim(),
            'allow_deposit': _depositOn ? 1 : 0,
            'allow_full_payment': _fullOn ? 1 : 0,
            'allow_pay_on_arrival': _arrivalOn ? 1 : 0,
          }),
          child: const Text('حفظ إعدادات الدفع'),
        ),
      ],
    );
  }
}

class _PhotosTab extends StatefulWidget {
  const _PhotosTab({required this.farm, required this.upload, required this.onSave});

  final Map<String, dynamic> farm;
  final Future<String> Function(Uint8List bytes, String name) upload;
  final Future<void> Function(List<String> urls) onSave;

  @override
  State<_PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends State<_PhotosTab> {
  late List<String> _urls;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _urls = [
      for (final e in (widget.farm['images'] as List? ?? []))
        if (e is Map && (e['url']?.toString().trim().isNotEmpty ?? false)) e['url'].toString(),
    ];
    final cover = widget.farm['cover_url']?.toString().trim() ?? '';
    if (cover.isNotEmpty && !_urls.contains(cover)) _urls.insert(0, cover);
  }

  Future<void> _add() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() => _busy = true);
    try {
      for (final file in files) {
        if (_urls.length >= 10) break;
        final bytes = await file.readAsBytes();
        final url = await widget.upload(bytes, file.name);
        if (url.isNotEmpty) _urls.add(url);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppResponsive.pagePadding(context, accountForShellNav: true),
      children: [
        const Text('حدّث صور المزرعة. الصورة الأولى هي الغلاف، ويمكن للزائر سحب الصور لتصفحها.'),
        const SizedBox(height: 12),
        if (_urls.isEmpty) const Text('لا توجد صور بعد'),
        for (var i = 0; i < _urls.length; i++)
          Card(
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                CachedNetworkImage(imageUrl: _urls[i], height: 160, width: double.infinity, fit: BoxFit.cover),
                Positioned(
                  top: 4,
                  left: 4,
                  child: IconButton.filledTonal(
                    onPressed: () => setState(() => _urls.removeAt(i)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _busy ? null : _add, icon: const Icon(Icons.add_photo_alternate), label: Text(_busy ? 'جارٍ الرفع' : 'إضافة صور')),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _urls.isEmpty || _busy ? null : () => widget.onSave(List<String>.from(_urls)),
          child: const Text('حفظ الصور'),
        ),
      ],
    );
  }
}
