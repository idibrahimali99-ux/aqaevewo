import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';

class AdminFarmsScreen extends ConsumerStatefulWidget {
  const AdminFarmsScreen({super.key});

  @override
  ConsumerState<AdminFarmsScreen> createState() => _AdminFarmsScreenState();
}

class _AdminFarmsScreenState extends ConsumerState<AdminFarmsScreen> {
  String _scope = 'all';
  String _sort = 'newest';
  final _query = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson('admin/farms', query: {'scope': _scope});
      final items = <Map<String, dynamic>>[];
      final raw = data['items'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) items.add(Map<String, dynamic>.from(e));
        }
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _act(String farmId, String action, {String note = ''}) async {
    final api = ref.read(vewoApiClientProvider);
    await api.postJson('admin/farms', {
      'farm_id': farmId,
      'action': action,
      if (note.isNotEmpty) 'reject_note': note,
    });
    await _load();
  }

  List<Map<String, dynamic>> get _shown {
    final q = _query.text.trim();
    final items = _items.where((farm) {
      if (q.isEmpty) return true;
      final blob = '${farm['name'] ?? ''} ${farm['public_code'] ?? ''} ${farm['city'] ?? ''} ${farm['phone'] ?? ''}';
      return blob.contains(q);
    }).toList();
    items.sort((a, b) {
      if (_sort == 'name') {
        return '${a['name'] ?? ''}'.compareTo('${b['name'] ?? ''}');
      }
      return '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}');
    });
    return items;
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              TextField(
                controller: _query,
                decoration: const InputDecoration(
                  hintText: 'ابحث بالاسم أو الرقم أو المدينة',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('الترتيب'),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _sort,
                    items: const [
                      DropdownMenuItem(value: 'newest', child: Text('الأحدث')),
                      DropdownMenuItem(value: 'name', child: Text('الاسم')),
                    ],
                    onChanged: (v) => setState(() => _sort = v ?? 'newest'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final item in const [
                      ('all', 'كل المزارع'),
                      ('pending', 'بانتظار الموافقة'),
                      ('approved', 'منشورة'),
                      ('rejected', 'مرفوضة'),
                      ('suspended', 'موقوفة'),
                    ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(item.$2),
                          selected: _scope == item.$1,
                          onSelected: (_) {
                            setState(() => _scope = item.$1);
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : shown.isEmpty
              ? const Center(child: Text('لا توجد مزارع في هذا القسم'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final farm = shown[index];
                    final id = farm['id']?.toString() ?? '';
                    final code = farm['public_code']?.toString() ?? '';
                    final cover = _coverOf(farm);
                    final status = '${farm['status'] ?? ''}';
                    final place = [
                      farm['governorate'],
                      farm['city'],
                      farm['district'],
                    ].whereType<Object>().map((e) => '$e'.trim()).where((e) => e.isNotEmpty).join(' · ');
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _AdminFarmDetail(farm: farm),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (cover.isNotEmpty)
                              CachedNetworkImage(imageUrl: cover, height: 140, width: double.infinity, fit: BoxFit.cover)
                            else
                              Container(
                                height: 88,
                                alignment: Alignment.center,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.agriculture, size: 36),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${farm['name'] ?? 'مزرعة'}',
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                        ),
                                      ),
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(_farmStatus(status)),
                                      ),
                                    ],
                                  ),
                                  if (code.isNotEmpty) Text('رقم المزرعة $code'),
                                  if (place.isNotEmpty) Text(place),
                                  if ((farm['phone']?.toString() ?? '').isNotEmpty) Text('${farm['phone']}'),
                                  Text(
                                    farm['booking_quota'] == null
                                        ? 'باقة الحجوزات: بلا حدود'
                                        : 'باقة الحجوزات: ${farm['booking_quota']} · المتبقي ${farm['bookings_remaining'] ?? 0}',
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (status != 'approved')
                                        FilledButton.tonalIcon(
                                          onPressed: () => _act(id, 'approve'),
                                          icon: const Icon(Icons.check, size: 18),
                                          label: const Text('موافقة'),
                                        ),
                                      if (status == 'pending')
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            final note = await _askNote(context);
                                            if (note == null || note.trim().isEmpty) return;
                                            await _act(id, 'reject', note: note.trim());
                                          },
                                          icon: const Icon(Icons.close, size: 18),
                                          label: const Text('رفض'),
                                        ),
                                      if (status == 'approved')
                                        OutlinedButton.icon(
                                          onPressed: () => _act(id, 'suspend'),
                                          icon: const Icon(Icons.pause, size: 18),
                                          label: const Text('إيقاف'),
                                        ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(builder: (_) => _AdminFarmDetail(farm: farm)),
                                        ),
                                        child: const Text('التفاصيل والحجوزات'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<String?> _askNote(BuildContext context) async {
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'اكتب السبب')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('رفض')),
        ],
      ),
    );
    ctrl.dispose();
    return note;
  }
}

String _farmStatus(String raw) {
  return switch (raw) {
    'approved' => 'منشورة',
    'pending' => 'بانتظار الموافقة',
    'rejected' => 'مرفوضة',
    'suspended' => 'موقوفة',
    'closed' => 'مغلقة',
    _ => raw,
  };
}

String _coverOf(Map<String, dynamic> farm) {
  final cover = farm['cover_url']?.toString().trim() ?? '';
  if (cover.isNotEmpty) return cover;
  final raw = farm['images'];
  if (raw is List && raw.isNotEmpty && raw.first is Map) {
    return raw.first['url']?.toString() ?? '';
  }
  return '';
}

class _AdminFarmDetail extends ConsumerStatefulWidget {
  const _AdminFarmDetail({required this.farm});

  final Map<String, dynamic> farm;

  @override
  ConsumerState<_AdminFarmDetail> createState() => _AdminFarmDetailState();
}

class _AdminFarmDetailState extends ConsumerState<_AdminFarmDetail> {
  bool _loading = true;
  List<Map<String, dynamic>> _bookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      final data = await ref.read(vewoApiClientProvider).getJson('admin/farm-bookings');
      final farmId = widget.farm['id']?.toString() ?? '';
      final items = <Map<String, dynamic>>[];
      final raw = data['items'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map && e['farm_id']?.toString() == farmId) {
            items.add(Map<String, dynamic>.from(e));
          }
        }
      }
      items.sort((a, b) => '${a['booking_date']} ${a['start_time']}'.compareTo('${b['booking_date']} ${b['start_time']}'));
      if (!mounted) return;
      setState(() {
        _bookings = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farm = widget.farm;
    final images = <String>[];
    final raw = farm['images'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final url = e['url']?.toString().trim() ?? '';
          if (url.isNotEmpty) images.add(url);
        }
      }
    }
    final cover = _coverOf(farm);
    if (cover.isNotEmpty && !images.contains(cover)) images.insert(0, cover);
    final shifts = farm['shifts'];
    final services = farm['services'];
    return Scaffold(
      appBar: AppBar(title: Text(farm['name']?.toString() ?? 'المزرعة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 220,
                child: PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (_, index) => CachedNetworkImage(imageUrl: images[index], fit: BoxFit.cover),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(farm['public_code']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
          Text('${farm['governorate'] ?? ''} ${farm['city'] ?? ''} ${farm['district'] ?? ''}'),
          Text('الهاتف: ${farm['phone'] ?? ''}'),
          if ((farm['description']?.toString() ?? '').isNotEmpty) Text(farm['description'].toString()),
          Text('حجوزات مكتملة: ${farm['bookings_completed'] ?? 0}'),
          Text('باقة الحجوزات: ${farm['booking_quota'] ?? 'بلا حد'}'),
          const SizedBox(height: 8),
          _QuotaEditor(farmId: farm['id']?.toString() ?? '', current: farm['booking_quota']?.toString() ?? ''),
          Text('العربون: ${farm['deposit_iqd'] ?? 0} د.ع'),
          Text('سوبر كي: ${farm['superqi_number'] ?? '—'}'),
          const SizedBox(height: 12),
          const Text('الشفتات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          if (shifts is! List || shifts.isEmpty)
            const Text('لا توجد شفتات')
          else
            for (final shift in shifts)
              if (shift is Map)
                Text('${shift['name'] ?? ''} · ${shift['start_time_12'] ?? shift['start_time'] ?? ''} - ${shift['end_time_12'] ?? shift['end_time'] ?? ''} · ${shift['base_price_iqd'] ?? 0} د.ع'),
          const SizedBox(height: 12),
          const Text('الخدمات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          if (services is! List || services.isEmpty)
            const Text('لا توجد خدمات')
          else
            for (final svc in services)
              if (svc is Map) Text('${svc['name'] ?? ''} · ${svc['price_iqd'] ?? 0} د.ع'),
          const SizedBox(height: 16),
          const Text('الحجوزات ووصولات الدفع', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          if (_loading)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else if (_bookings.isEmpty)
            const Text('لا توجد حجوزات')
          else
            for (final b in _bookings)
              Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: _adminStatusColor('${b['booking_status'] ?? ''}')),
                ),
                child: InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _AdminBookingDetail(booking: b, farmName: farm['name']?.toString() ?? ''))),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${b['public_code'] ?? ''} · ${b['customer_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('موعد الحجز: ${b['booking_date'] ?? ''} · ${b['shift_name'] ?? ''} ${b['start_time_12'] ?? ''} - ${b['end_time_12'] ?? ''}'),
                        Text('أُنشئ: ${b['created_at'] ?? '—'}'),
                        Text('المدفوع ${b['paid_iqd'] ?? 0} من ${b['total_iqd'] ?? 0} · ${_adminBookStatus('${b['booking_status'] ?? ''}')}'),
                        if ((b['proof_url']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(imageUrl: b['proof_url'].toString(), height: 140, width: double.infinity, fit: BoxFit.cover),
                          ),
                        ],
                        const SizedBox(height: 4),
                        const Text('اضغط لعرض التفاصيل الكاملة', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _QuotaEditor extends ConsumerStatefulWidget {
  const _QuotaEditor({required this.farmId, required this.current});

  final String farmId;
  final String current;

  @override
  ConsumerState<_QuotaEditor> createState() => _QuotaEditorState();
}

class _QuotaEditorState extends ConsumerState<_QuotaEditor> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'باقة عدد الحجوزات'),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () async {
            await ref.read(vewoApiClientProvider).postJson('admin/farms', {
              'farm_id': widget.farmId,
              'action': 'set_quota',
              'booking_quota': _ctrl.text.trim(),
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ باقة الحجوزات')));
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

Color _adminStatusColor(String raw) {
  return switch (raw) {
    'confirmed' || 'completed' => const Color(0xFF2E7D32),
    'rejected' || 'cancelled' => const Color(0xFFC62828),
    'payment_proof_uploaded' || 'awaiting_confirmation' => const Color(0xFFE65100),
    _ => const Color(0xFF1565C0),
  };
}

String _adminBookStatus(String raw) {
  return switch (raw) {
    'payment_pending' || 'pending' => 'بانتظار الدفع',
    'payment_proof_uploaded' => 'وصل مرفوع',
    'awaiting_confirmation' => 'بانتظار التأكيد',
    'confirmed' => 'مؤكد',
    'completed' => 'مكتمل',
    'cancelled' => 'ملغى',
    'rejected' => 'مرفوض',
    _ => raw,
  };
}

String _payMethod(String raw) {
  return switch (raw) {
    'deposit' => 'عربون',
    'full' => 'دفع كامل',
    'on_arrival' => 'عند الوصول',
    _ => raw,
  };
}

class _AdminBookingDetail extends StatelessWidget {
  const _AdminBookingDetail({required this.booking, required this.farmName});

  final Map<String, dynamic> booking;
  final String farmName;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final proof = b['proof_url']?.toString() ?? '';
    String line(String label, Object? value) => '$label: ${value ?? '—'}';
    return Scaffold(
      appBar: AppBar(title: Text('${b['public_code'] ?? 'حجز'}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(farmName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 8),
          Text(line('الحالة', _adminBookStatus('${b['booking_status'] ?? ''}'))),
          Text(line('حالة الدفع', b['payment_status'])),
          Text(line('طريقة الدفع', _payMethod('${b['payment_method'] ?? ''}'))),
          Text(line('الزبون', b['customer_name'])),
          Text(line('الهاتف', b['customer_phone'])),
          Text(line('موعد الحجز', '${b['booking_date'] ?? ''} · ${b['shift_name'] ?? ''}')),
          Text(line('وقت الشفت', '${b['start_time_12'] ?? b['start_time'] ?? ''} - ${b['end_time_12'] ?? b['end_time'] ?? ''}')),
          Text(line('تاريخ إنشاء الحجز', b['created_at'])),
          Text(line('الأشخاص', b['people_count'])),
          Text(line('الإجمالي', '${b['total_iqd'] ?? 0} د.ع')),
          Text(line('العربون', '${b['deposit_iqd'] ?? 0} د.ع')),
          Text(line('المدفوع', '${b['paid_iqd'] ?? 0} د.ع')),
          Text(line('المتبقي', '${b['remaining_iqd'] ?? 0} د.ع')),
          if ((b['note']?.toString() ?? '').isNotEmpty) Text(line('ملاحظة', b['note'])),
          if ((b['hold_until']?.toString() ?? '').isNotEmpty) Text(line('مهلة الدفع حتى', b['hold_until'])),
          const SizedBox(height: 12),
          const Text('وصل الدفع', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          if (proof.isEmpty)
            const Text('لم يُرفع وصل')
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(imageUrl: proof, height: 280, width: double.infinity, fit: BoxFit.contain),
            ),
        ],
      ),
    );
  }
}
