import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_responsive.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../../routing/app_routes.dart';
import '../../auth/data/auth_controller.dart';

class FarmProfileScreen extends ConsumerStatefulWidget {
  const FarmProfileScreen({super.key, required this.farmId});

  final String farmId;

  @override
  ConsumerState<FarmProfileScreen> createState() => _FarmProfileScreenState();
}

class _FarmProfileScreenState extends ConsumerState<FarmProfileScreen> {
  Map<String, dynamic>? _farm;
  List<Map<String, dynamic>> _shifts = [];
  DateTime _date = DateTime.now();
  bool _loading = true;
  String? _error;
  String? _shiftId;
  String _payment = 'on_arrival';
  final Set<String> _serviceIds = {};
  int _people = 1;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> get _paidServices {
    final raw = _farm?['services'];
    if (raw is! List) return [];
    return [
      for (final e in raw)
        if (e is Map && (e['is_active'] == 1 || e['is_active'] == true))
          Map<String, dynamic>.from(e),
    ];
  }

  List<(String, String)> get _payOptions {
    final farm = _farm ?? {};
    bool on(String key) => farm[key] == 1 || farm[key] == true;
    final options = <(String, String)>[
      if (on('allow_deposit')) ('deposit', 'عربون'),
      if (on('allow_full_payment')) ('full', 'دفع كامل'),
      if (on('allow_pay_on_arrival')) ('on_arrival', 'عند الوصول'),
    ];
    if (options.isEmpty) return [('on_arrival', 'عند الوصول')];
    return options;
  }

  String get _dateText {
    final d = _date;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final detail = await api.getJson('farms/get', query: {'id': widget.farmId});
      final item = detail['item'];
      final avail = await api.getJson(
        'farms/availability',
        query: {'farm_id': widget.farmId, 'date': _dateText},
      );
      final shifts = <Map<String, dynamic>>[];
      final raw = avail['shifts'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) shifts.add(Map<String, dynamic>.from(e));
        }
      }
      if (!mounted) return;
      setState(() {
        _farm = item is Map ? Map<String, dynamic>.from(item) : {};
        _shifts = shifts;
        _shiftId = shifts.cast<Map<String, dynamic>?>().firstWhere(
          (s) => s?['available'] == 1 || s?['available'] == true,
          orElse: () => shifts.isEmpty ? null : shifts.first,
        )?['id']?.toString();
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
        _error = 'تعذر فتح المزرعة';
        _loading = false;
      });
    }
  }

  Future<bool> _uploadProof(String bookingId) async {
    final amount = TextEditingController();
    Uint8List? bytes;
    final account = _farm?['superqi_number']?.toString().trim() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('رفع صورة الدفع'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('لن يُسجل الحجز إلا بعد إرسال صورة الوصل والمبلغ. إذا أغلقت هذه النافذة دون إرسال، لا يُنشأ حجز.'),
                const SizedBox(height: 12),
                const _PayBrands(),
                const SizedBox(height: 12),
                _AccountCopy(account: account),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ الذي تم دفعه'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
                    if (file == null) return;
                    bytes = await file.readAsBytes();
                    setLocal(() {});
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(bytes == null ? 'رفع صورة الوصل' : 'تم اختيار صورة الوصل'),
                ),
              ],
            ),
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
    if (ok != true || bytes == null || paid <= 0 || !mounted) return false;
    final up = await ref.read(vewoApiClientProvider).postMultipartBytes(
      'farms/upload',
      'file',
      bytes!,
      'proof.jpg',
    );
    final url = up['public_url']?.toString() ?? up['url']?.toString() ?? '';
    await ref.read(vewoApiClientProvider).postJson('farms/booking/proof', {
      'booking_id': bookingId,
      'proof_url': url,
      'paid_iqd': paid,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال إثبات الدفع')));
    }
    return true;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      initialDate: _date,
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await _load();
  }

  Future<void> _book() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      context.push(AppRoutes.login);
      return;
    }
    if (auth.isFarm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حساب المزرعة لا يحجز كمزرعة أخرى')),
      );
      return;
    }
    final shift = _shiftId;
    if (shift == null || shift.isEmpty) return;
    setState(() => _booking = true);
    String? pendingPayId;
    try {
      final data = await ref.read(vewoApiClientProvider).postJson('farms/book', {
        'farm_id': widget.farmId,
        'shift_id': shift,
        'booking_date': _dateText,
        'people_count': _people,
        'cars_count': 0,
        'payment_method': _payment,
        'service_ids': _serviceIds.toList(),
      });
      if (!mounted) return;
      final item = data['item'];
      final code = item is Map ? (item['public_code']?.toString() ?? '') : '';
      final bookingId = item is Map ? item['id']?.toString() ?? '' : '';
      if (_payment != 'on_arrival' && bookingId.isNotEmpty) {
        pendingPayId = bookingId;
        final paidOk = await _uploadProof(bookingId);
        if (!paidOk) {
          try {
            await ref.read(vewoApiClientProvider).postJson('farms/booking/cancel', {'booking_id': bookingId});
          } catch (_) {}
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يُسجل الحجز لأن الدفع لم يُؤكد')),
          );
          pendingPayId = null;
          return;
        }
        pendingPayId = null;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(code.isEmpty ? 'تم تسجيل الحجز' : 'رقم الحجز $code')),
      );
      context.push(AppRoutes.myFarmBookings);
    } on VewoApiException catch (e) {
      if (pendingPayId != null) {
        try {
          await ref.read(vewoApiClientProvider).postJson('farms/booking/cancel', {'booking_id': pendingPayId});
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farm = _farm ?? {};
    final name = farm['name']?.toString() ?? 'مزرعة';
    final code = farm['public_code']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: AppResponsive.pagePadding(context, accountForShellNav: true),
              children: [
                _FarmGallery(farm: farm),
                const SizedBox(height: 12),
                Text(name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                if (code.isNotEmpty)
                  Text('رقم المزرعة $code', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text([
                  farm['governorate'],
                  farm['city'],
                  farm['district'],
                ].whereType<Object>().map((e) => '$e'.trim()).where((e) => e.isNotEmpty).join(' · ')),
                if ((farm['description']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(farm['description'].toString()),
                ],
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('تاريخ الحجز', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(_dateText),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(height: 16),
                Text('الخدمات المتوفرة', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                _AmenityWrap(farm: farm),
                const SizedBox(height: 12),
                Text('خدمات بسعر', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                if (_paidServices.isEmpty)
                  const Text('لا توجد خدمات إضافية حالياً')
                else
                  ..._paidServices.map((svc) {
                    final id = svc['id']?.toString() ?? '';
                    return CheckboxListTile(
                      value: _serviceIds.contains(id),
                      onChanged: (on) => setState(() {
                        if (on == true) {
                          _serviceIds.add(id);
                        } else {
                          _serviceIds.remove(id);
                        }
                      }),
                      title: Text('${svc['name'] ?? ''} · ${svc['price_iqd'] ?? 0} د.ع'),
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                const SizedBox(height: 16),
                Text('اختر الشفت', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (_shifts.isEmpty)
                  const Text('لا توجد شفتات لهذا اليوم')
                else
                  ..._shifts.map((shift) {
                    final id = shift['id']?.toString() ?? '';
                    final status = shift['status']?.toString() ?? 'available';
                    final available = status == 'available';
                    final selected = _shiftId == id;
                    final title = '${shift['name'] ?? 'شفت'} · ${shift['start_time_12'] ?? shift['start_time'] ?? ''} - ${shift['end_time_12'] ?? shift['end_time'] ?? ''}';
                    final tone = _shiftTone(context, status, selected);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: tone.$1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: tone.$2, width: 1.4),
                      ),
                      child: ListTile(
                        enabled: available,
                        onTap: available ? () => setState(() => _shiftId = id) : null,
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${_shiftLabel(status)} · ${shift['price_iqd'] ?? shift['base_price_iqd'] ?? 0} د.ع'),
                        trailing: Icon(
                          status == 'confirmed' ? Icons.check_circle : (selected ? Icons.radio_button_checked : Icons.circle_outlined),
                          color: tone.$2,
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                if ((farm['superqi_number']?.toString() ?? '').isNotEmpty)
                  Text('سوبر كي: ${farm['superqi_number']}'),
                if ((farm['deposit_iqd'] ?? 0) != 0)
                  Text('العربون: ${farm['deposit_iqd']} د.ع'),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final current = _payOptions.any((e) => e.$1 == _payment)
                        ? _payment
                        : _payOptions.first.$1;
                    return DropdownButtonFormField<String>(
                      initialValue: current,
                      decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                      items: [
                        for (final opt in _payOptions)
                          DropdownMenuItem(value: opt.$1, child: Text(opt.$2)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _payment = v);
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('الأشخاص'),
                    const Spacer(),
                    IconButton(onPressed: _people > 1 ? () => setState(() => _people--) : null, icon: const Icon(Icons.remove)),
                    Text('$_people'),
                    IconButton(onPressed: () => setState(() => _people++), icon: const Icon(Icons.add)),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _booking || _shiftId == null ? null : _book,
                  child: Text(_booking ? 'جارٍ الحجز' : 'تأكيد الحجز'),
                ),
              ],
            ),
    );
  }
}

(Color?, Color) _shiftTone(BuildContext context, String status, bool selected) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    'held' => (const Color(0xFFFFF4E5), const Color(0xFFE65100)),
    'confirmed' => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
    'ended' => (scheme.surfaceContainerHighest, scheme.outline),
    _ => (selected ? scheme.primaryContainer : scheme.surface, selected ? scheme.primary : scheme.outlineVariant),
  };
}

String _shiftLabel(String status) {
  return switch (status) {
    'held' => 'محجوز مؤقتاً',
    'confirmed' => 'تم التأكيد',
    'ended' => 'انتهى',
    _ => 'متاح',
  };
}

class _PayBrands extends StatelessWidget {
  const _PayBrands();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _BrandPill(icon: Icons.account_balance_wallet_outlined, title: 'سوبر كي', color: Color(0xFF0B7A4B))),
        SizedBox(width: 8),
        Expanded(child: _BrandPill(icon: Icons.credit_card, title: 'كي كارد', color: Color(0xFF1565C0))),
      ],
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill({required this.icon, required this.title, required this.color});

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _AccountCopy extends StatelessWidget {
  const _AccountCopy({required this.account});

  final String account;

  @override
  Widget build(BuildContext context) {
    final shown = account.isEmpty ? 'لم يُحدد رقم الحساب' : account;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(child: Text('رقم الحساب: $shown', style: const TextStyle(fontWeight: FontWeight.w800))),
          if (account.isNotEmpty)
            IconButton(
              tooltip: 'نسخ',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: account));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رقم الحساب')));
              },
              icon: const Icon(Icons.copy),
            ),
        ],
      ),
    );
  }
}

class _AmenityWrap extends StatelessWidget {
  const _AmenityWrap({required this.farm});

  final Map<String, dynamic> farm;

  @override
  Widget build(BuildContext context) {
    final labels = farm['amenity_labels'];
    final ids = farm['amenities'];
    if (ids is! List || ids.isEmpty) {
      return const Text('لم تُحدد خدمات بعد');
    }
    final names = <String>[];
    for (final id in ids) {
      final key = id.toString();
      final label = labels is Map ? labels[key]?.toString() : null;
      names.add((label == null || label.isEmpty) ? key : label);
    }
    final catalog = farm['amenity_catalog'];
    final selected = ids.map((e) => e.toString()).toSet();
    if (catalog is! List) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (final name in names) Chip(label: Text(name))],
      );
    }
    final groups = <Widget>[];
    for (final group in catalog) {
      if (group is! Map) continue;
      final items = group['items'];
      if (items is! List) continue;
      final picked = <String>[];
      for (final item in items) {
        if (item is Map && selected.contains('${item['id']}')) {
          picked.add('${item['label'] ?? item['id']}');
        }
      }
      if (picked.isEmpty) continue;
      groups.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${group['label'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final name in picked) Chip(label: Text(name))]),
          ],
        ),
      ));
    }
    if (groups.isEmpty) {
      return Wrap(spacing: 6, children: [for (final name in names) Chip(label: Text(name))]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: groups);
  }
}

class _FarmGallery extends StatefulWidget {
  const _FarmGallery({required this.farm});

  final Map<String, dynamic> farm;

  @override
  State<_FarmGallery> createState() => _FarmGalleryState();
}

class _FarmGalleryState extends State<_FarmGallery> {
  int _page = 0;

  List<String> get _urls {
    final urls = <String>[];
    final raw = widget.farm['images'];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final url = e['url']?.toString().trim() ?? '';
          if (url.isNotEmpty) urls.add(url);
        }
      }
    }
    final cover = widget.farm['cover_url']?.toString().trim() ?? '';
    if (cover.isNotEmpty && !urls.contains(cover)) urls.insert(0, cover);
    return urls;
  }

  void _open(List<String> urls, int index) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _PhotoViewer(urls: urls, initial: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 240,
            child: PageView.builder(
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _open(urls, index),
                child: CachedNetworkImage(imageUrl: urls[index], fit: BoxFit.cover),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('اسحب لعرض الصور · ${_page + 1}/${urls.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.urls, required this.initial});

  final List<String> urls;
  final int initial;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _ctrl;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initial;
    _ctrl = PageController(initialPage: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_page + 1} / ${widget.urls.length}'),
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (_, index) => InteractiveViewer(
          child: CachedNetworkImage(imageUrl: widget.urls[index], fit: BoxFit.contain),
        ),
      ),
    );
  }
}
