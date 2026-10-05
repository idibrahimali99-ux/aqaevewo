import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_responsive.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../../routing/app_routes.dart';
import '../../auth/data/auth_controller.dart';

class FarmHubScreen extends ConsumerStatefulWidget {
  const FarmHubScreen({super.key});

  @override
  ConsumerState<FarmHubScreen> createState() => _FarmHubScreenState();
}

class _FarmHubScreenState extends ConsumerState<FarmHubScreen> {
  Map<String, dynamic>? _farm;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  String? _error;

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
      final mine = await api.getJson('farms/owner/dashboard');
      final bookings = await api.getJson('farms/owner/bookings');
      final items = <Map<String, dynamic>>[];
      final raw = bookings['items'];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) items.add(Map<String, dynamic>.from(e));
        }
      }
      if (!mounted) return;
      final item = mine['item'];
      setState(() {
        _farm = item is Map ? Map<String, dynamic>.from(item) : {};
        final stats = mine['stats'];
        _stats = stats is Map ? Map<String, dynamic>.from(stats) : {};
        _bookings = items;
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
        _error = 'تعذر فتح لوحة المزرعة';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final farm = _farm ?? {};
    final name = farm['name']?.toString().trim().isNotEmpty == true
        ? farm['name'].toString()
        : (auth.farmName.isEmpty ? 'مزرعتي' : auth.farmName);
    final code = farm['public_code']?.toString().trim().isNotEmpty == true
        ? farm['public_code'].toString()
        : auth.farmPublicCode;
    final status = farm['status']?.toString() ?? auth.farmStatus;
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المزرعة'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'الأقسام',
            icon: const Icon(Icons.menu),
            onSelected: (value) {
              if (value == 'shifts') {
                context.push('${AppRoutes.farmManage}?tab=0');
              } else if (value == 'services') {
                context.push('${AppRoutes.farmManage}?tab=1');
              } else if (value == 'payment') {
                context.push('${AppRoutes.farmManage}?tab=2');
              } else if (value == 'photos') {
                context.push('${AppRoutes.farmManage}?tab=3');
              } else if (value == 'bookings') {
                context.push(AppRoutes.myFarmBookings);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'shifts', child: Text('الشفتات')),
              PopupMenuItem(value: 'services', child: Text('الخدمات')),
              PopupMenuItem(value: 'payment', child: Text('إعدادات الدفع')),
              PopupMenuItem(value: 'photos', child: Text('صور المزرعة')),
              PopupMenuItem(value: 'bookings', child: Text('الحجوزات')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: AppResponsive.pagePadding(context, accountForShellNav: true),
                children: [
                  Text(name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  if (code.isNotEmpty) Text('رقم المزرعة $code', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('الحالة: ${_statusAr(status)}'),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: const Text('باقة الحجوزات', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        farm['booking_quota'] == null
                            ? 'تم ${farm['bookings_used'] ?? 0} حجز · باقة بلا حدود'
                            : 'تم ${farm['bookings_used'] ?? 0} حجز · المتبقي ${farm['bookings_remaining'] ?? 0}',
                      ),
                    ),
                  ),
                  if ((farm['reject_note']?.toString() ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('سبب الرفض: ${farm['reject_note']}'),
                    ),
                  const SizedBox(height: 8),
                  if (status != 'approved')
                    const Text('الحساب بانتظار موافقة الإدارة. بعد الموافقة يمكنك نشر الريلز واستقبال الحجوزات.'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Stat('اليوم', _stats['today']),
                      _Stat('قادمة', _stats['upcoming']),
                      _Stat('بانتظار', _stats['pending']),
                      _Stat('مؤكدة', _stats['confirmed']),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.farmManage),
                    icon: const Icon(Icons.schedule),
                    label: const Text('الشفتات والخدمات'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: status == 'approved'
                        ? () => context.push('${AppRoutes.reels}?compose=1')
                        : null,
                    icon: const Icon(Icons.video_collection_outlined),
                    label: const Text('نشر ريل'),
                  ),
                  const SizedBox(height: 16),
                  Text('الحجوزات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('عدد الحجوزات: ${_bookings.length}'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => context.push(AppRoutes.myFarmBookings),
                    icon: const Icon(Icons.event_note),
                    label: const Text('فتح قسم الحجوزات'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: ${value ?? 0}'));
  }
}

String _statusAr(String raw) {
  return switch (raw) {
    'approved' => 'منشورة',
    'pending' => 'قيد المراجعة',
    'rejected' => 'مرفوضة',
    'suspended' => 'موقوفة',
    'closed' => 'مغلقة',
    _ => raw.isEmpty ? 'قيد المراجعة' : raw,
  };
}
