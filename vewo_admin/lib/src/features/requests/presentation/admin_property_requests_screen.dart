import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

class AdminPropertyRequestsScreen extends ConsumerStatefulWidget {
  const AdminPropertyRequestsScreen({super.key});

  @override
  ConsumerState<AdminPropertyRequestsScreen> createState() =>
      _AdminPropertyRequestsScreenState();
}

class _AdminPropertyRequestsScreenState
    extends ConsumerState<AdminPropertyRequestsScreen> {
  final _search = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _status = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(vewoApiClientProvider)
          .getJson(
            'admin/property-requests',
            query: {
              if (_status.isNotEmpty) 'status': _status,
              if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
              if (_from.text.trim().isNotEmpty) 'from': _from.text.trim(),
              if (_to.text.trim().isNotEmpty) 'to': _to.text.trim(),
            },
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
        _error = 'تعذر تحميل الطلبات';
        _loading = false;
      });
    }
  }

  Future<void> _setStatus(Map<String, dynamic> item, String status) async {
    try {
      await ref.read(vewoApiClientProvider).postJson(
        'admin/property-requests',
        {'id': item['id'], 'status': status},
      );
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _launchPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.isEmpty) return;
    await launchUrl(
      Uri(scheme: 'tel', path: clean),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _launchWhatsapp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    await launchUrl(
      Uri.parse('https://wa.me/964$local'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _openDetails(Map<String, dynamic> item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        minChildSize: .45,
        maxChildSize: .95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'طلب #${item['request_no']}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.phone_outlined),
                  label: const Text('اتصال'),
                  onPressed: () =>
                      _launchPhone(item['phone']?.toString() ?? ''),
                ),
                ActionChip(
                  avatar: const Icon(Icons.chat_outlined),
                  label: const Text('واتساب'),
                  onPressed: () =>
                      _launchWhatsapp(item['phone']?.toString() ?? ''),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _statusChip(context, item['status']),
            ),
            const SizedBox(height: 12),
            _row('الزبون', item['customer_name']),
            _row('الهاتف', item['phone']),
            _row('النوع', _purpose(item['purpose'])),
            _row('القسم', _category(item['category'])),
            _row('المحافظة', item['governorate']),
            _row(
              'المساحة',
              '${item['area_min'] ?? '-'} - ${item['area_max'] ?? '-'} م²',
            ),
            _row(
              'السعر',
              '${item['price_min'] ?? '-'} - ${item['price_max'] ?? '-'}',
            ),
            _row('الوصف', item['description']),
            const SizedBox(height: 18),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: Text('انتظار')),
                ButtonSegment(value: 'in_progress', label: Text('تنفيذ')),
                ButtonSegment(value: 'closed', label: Text('مغلق')),
              ],
              selected: {item['status']?.toString() ?? 'pending'},
              onSelectionChanged: (v) {
                Navigator.pop(context);
                _setStatus(item, v.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات العقار')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _search,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'بحث برقم الطلب',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _from,
                    decoration: const InputDecoration(
                      labelText: 'من تاريخ',
                      hintText: '2026-06-01',
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _to,
                    decoration: const InputDecoration(
                      labelText: 'إلى تاريخ',
                      hintText: '2026-06-30',
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('كل الحالات')),
                    DropdownMenuItem(value: 'pending', child: Text('انتظار')),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('تنفيذ'),
                    ),
                    DropdownMenuItem(value: 'closed', child: Text('مغلق')),
                  ],
                  onChanged: (v) {
                    setState(() => _status = v ?? '');
                    _load();
                  },
                ),
                IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final statusColor = _statusColor(context, item['status']);
                      return Card(
                        color: statusColor.withValues(alpha: .08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: statusColor.withValues(alpha: .35),
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withValues(alpha: .16),
                            child: Icon(
                              Icons.assignment_outlined,
                              color: statusColor,
                            ),
                          ),
                          title: Text(
                            '#${item['request_no']} - ${_category(item['category'])}',
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _statusChip(context, item['status']),
                                Text('${item['governorate'] ?? ''}'),
                                Text('${item['phone'] ?? ''}'),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_left_rounded),
                          onTap: () => _openDetails(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(text),
        ],
      ),
    );
  }

  String _statusLabel(Object? s) => switch (s?.toString()) {
    'in_progress' => 'قيد التنفيذ',
    'closed' => 'مغلق نهائياً',
    _ => 'قيد الانتظار',
  };

  Color _statusColor(BuildContext context, Object? status) {
    return switch (status?.toString()) {
      'in_progress' => Colors.orange.shade700,
      'closed' => Colors.green.shade700,
      _ => Colors.amber.shade800,
    };
  }

  Widget _statusChip(BuildContext context, Object? status) {
    final color = _statusColor(context, status);
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(_statusLabel(status)),
      backgroundColor: color.withValues(alpha: .14),
      side: BorderSide(color: color.withValues(alpha: .42)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w800),
    );
  }

  String _purpose(Object? v) => v == 'rent' ? 'إيجار' : 'شراء';

  String _category(Object? v) => switch (v?.toString()) {
    'parcel' => 'مقاطعات',
    'house' => 'بيوت',
    'apartment' => 'شقق',
    'shop' => 'محلات',
    'villa' => 'فلل',
    'compound' => 'مجمع سكني',
    _ => 'أراضي',
  };
}
