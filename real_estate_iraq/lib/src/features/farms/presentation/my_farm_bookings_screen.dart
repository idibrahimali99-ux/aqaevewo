import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/layout/app_responsive.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../auth/data/auth_controller.dart';

class MyFarmBookingsScreen extends ConsumerStatefulWidget {
  const MyFarmBookingsScreen({super.key});

  @override
  ConsumerState<MyFarmBookingsScreen> createState() => _MyFarmBookingsScreenState();
}

class _MyFarmBookingsScreenState extends ConsumerState<MyFarmBookingsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _filter = 'all';

  static const _filters = <(String, String)>[
    ('all', 'الكل'),
    ('waiting_pay', 'بانتظار الدفع'),
    ('waiting_confirm', 'بانتظار التأكيد'),
    ('confirmed', 'مؤكدة'),
    ('rejected', 'مرفوضة'),
  ];

  static const _reasons = <(String, String)>[
    ('short_amount', 'نقص في المبلغ'),
    ('unpaid', 'لم يتم الدفع'),
    ('unclear_proof', 'الوصل غير واضح'),
    ('unavailable', 'الموعد غير متاح'),
    ('other', 'سبب آخر'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _owner => ref.read(authControllerProvider).isFarm;

  bool _matches(Map<String, dynamic> b) {
    final st = b['booking_status']?.toString() ?? '';
    return switch (_filter) {
      'waiting_pay' => st == 'pending' || st == 'payment_pending',
      'waiting_confirm' => st == 'payment_proof_uploaded' || st == 'awaiting_confirmation',
      'confirmed' => st == 'confirmed' || st == 'completed',
      'rejected' => st == 'rejected' || st == 'cancelled',
      _ => true,
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final route = _owner ? 'farms/owner/bookings' : 'farms/my-bookings';
      final data = await ref.read(vewoApiClientProvider).getJson(route);
      final items = <Map<String, dynamic>>[];
      final raw = data['items'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) items.add(Map<String, dynamic>.from(e));
        }
      }
      items.sort((a, b) {
        final da = '${a['booking_date'] ?? ''} ${a['start_time'] ?? ''}';
        final db = '${b['booking_date'] ?? ''} ${b['start_time'] ?? ''}';
        return db.compareTo(da);
      });
      if (!mounted) return;
      setState(() {
        _items = items;
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
        _error = 'تعذر تحميل الحجوزات';
        _loading = false;
      });
    }
  }

  Future<void> _decide(String bookingId, String decision, {String reason = '', String note = ''}) async {
    await ref.read(vewoApiClientProvider).postJson('farms/owner/decide', {
      'booking_id': bookingId,
      'decision': decision,
      if (reason.isNotEmpty) 'reject_reason': reason,
      if (note.isNotEmpty) 'reject_note': note,
    });
    await _load();
  }

  Future<void> _reject(String bookingId) async {
    var selected = _reasons.first.$1;
    final extra = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('سبب الرفض'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final reason in _reasons)
                RadioListTile<String>(
                  value: reason.$1,
                  groupValue: selected,
                  title: Text(reason.$2),
                  onChanged: (v) => setLocal(() => selected = v ?? selected),
                ),
              if (selected == 'other')
                TextField(
                  controller: extra,
                  decoration: const InputDecoration(labelText: 'اكتب السبب'),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('رفض الحجز')),
          ],
        ),
      ),
    );
    final note = selected == 'other' ? extra.text.trim() : _reasons.firstWhere((e) => e.$1 == selected).$2;
    extra.dispose();
    if (ok != true || !mounted) return;
    if (selected == 'other' && note.isEmpty) return;
    try {
      await _decide(bookingId, 'reject', reason: selected, note: note);
    } on VewoApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _pay(String bookingId) async {
    if (bookingId.isEmpty) return;
    final amount = TextEditingController();
    Uint8List? bytes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('إثبات الدفع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ الذي تم دفعه'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
                  if (file == null) return;
                  bytes = await file.readAsBytes();
                  setLocal(() {});
                },
                child: Text(bytes == null ? 'رفع صورة الدفع' : 'تم اختيار الصورة'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال')),
          ],
        ),
      ),
    );
    final paid = int.tryParse(amount.text.trim()) ?? 0;
    amount.dispose();
    if (ok != true || bytes == null || paid <= 0 || !mounted) return;
    try {
      final api = ref.read(vewoApiClientProvider);
      final up = await api.postMultipartBytes('farms/upload', 'file', bytes!, 'proof.jpg');
      final url = up['public_url']?.toString() ?? up['url']?.toString() ?? '';
      await api.postJson('farms/booking/proof', {
        'booking_id': bookingId,
        'proof_url': url,
        'paid_iqd': paid,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال إثبات الدفع')));
      }
      await _load();
    } on VewoApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(authControllerProvider).isFarm;
    final shown = _items.where(_matches).toList();
    return Scaffold(
      appBar: AppBar(title: Text(owner ? 'حجوزات مزرعتي' : 'حجوزاتي')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                if (owner)
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      children: [
                        for (final f in _filters)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: ChoiceChip(
                              label: Text(f.$2),
                              selected: _filter == f.$1,
                              onSelected: (_) => setState(() => _filter = f.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: shown.isEmpty
                      ? const Center(child: Text('لا توجد حجوزات في هذا القسم'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: AppResponsive.pagePadding(context, accountForShellNav: true),
                            itemCount: shown.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final b = shown[index];
                              final st = b['booking_status']?.toString() ?? '';
                              final proof = b['proof_url']?.toString() ?? '';
                              final canConfirm = owner && (st == 'payment_proof_uploaded' || st == 'awaiting_confirmation');
                              final tone = _statusColor(st);
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: tone.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(_bookStatus(st), style: TextStyle(color: tone, fontWeight: FontWeight.w800)),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        owner
                                            ? '${b['public_code'] ?? ''} · ${b['customer_name'] ?? 'زبون'}'
                                            : (b['farm_name']?.toString() ?? 'مزرعة'),
                                        style: const TextStyle(fontWeight: FontWeight.w900),
                                      ),
                                      Text('${b['booking_date'] ?? ''} · ${b['shift_name'] ?? ''} · ${b['start_time_12'] ?? ''} - ${b['end_time_12'] ?? ''}'),
                                      Text('المدفوع ${b['paid_iqd'] ?? 0} من ${b['total_iqd'] ?? 0} د.ع'),
                                      if (owner)
                                        SelectableText(
                                          'رقم الحاجز: ${(b['customer_phone']?.toString() ?? '').trim().isEmpty ? 'غير مسجل' : b['customer_phone']}',
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                      if ((b['reject_note']?.toString() ?? '').isNotEmpty)
                                        Text('سبب الرفض: ${b['reject_note']}'),
                                      if (proof.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: CachedNetworkImage(imageUrl: proof, height: 160, width: double.infinity, fit: BoxFit.cover),
                                        ),
                                      ],
                                      if (canConfirm) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: FilledButton(
                                                onPressed: () => _decide(b['id']?.toString() ?? '', 'accept'),
                                                child: const Text('تأكيد الحجز'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton(
                                              onPressed: () => _reject(b['id']?.toString() ?? ''),
                                              child: const Text('رفض'),
                                            ),
                                          ],
                                        ),
                                      ] else if (!owner &&
                                          b['payment_method']?.toString() != 'on_arrival' &&
                                          st != 'payment_proof_uploaded' &&
                                          st != 'confirmed' &&
                                          st != 'cancelled' &&
                                          st != 'rejected')
                                        TextButton(
                                          onPressed: () => _pay(b['id']?.toString() ?? ''),
                                          child: const Text('رفع الوصل'),
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
            ),
    );
  }
}

Color _statusColor(String raw) {
  return switch (raw) {
    'confirmed' || 'completed' => const Color(0xFF2E7D32),
    'rejected' || 'cancelled' => const Color(0xFFC62828),
    'payment_proof_uploaded' || 'awaiting_confirmation' => const Color(0xFFE65100),
    _ => const Color(0xFF1565C0),
  };
}

String _bookStatus(String raw) {
  return switch (raw) {
    'payment_pending' || 'pending' => 'بانتظار الدفع',
    'payment_proof_uploaded' => 'وصل مرفوع — بانتظار التأكيد',
    'awaiting_confirmation' => 'بانتظار التأكيد',
    'confirmed' => 'مؤكد',
    'completed' => 'مكتمل',
    'cancelled' => 'ملغى',
    'rejected' => 'مرفوض',
    _ => raw,
  };
}
