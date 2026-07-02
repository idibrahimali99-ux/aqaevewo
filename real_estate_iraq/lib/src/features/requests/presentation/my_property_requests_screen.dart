import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_brand_mark.dart';
import '../data/property_requests_provider.dart';

class MyPropertyRequestsScreen extends ConsumerWidget {
  const MyPropertyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPropertyRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const AppBarBrandTitle('طلباتي العقارية')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myPropertyRequestsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('تعذر تحميل الطلبات')),
          data: (items) {
            if (items.isEmpty) {
              return const Center(child: Text('لا توجد طلبات عقار حتى الآن.'));
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _RequestCard(item: items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? 'pending';
    final color = switch (status) {
      'in_progress' => Colors.orange,
      'closed' => Colors.green,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '#${item['request_no'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Chip(
                  label: Text(_statusLabel(status)),
                  backgroundColor: color.withValues(alpha: .12),
                  labelStyle: TextStyle(color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_purpose(item['purpose'])} - ${_category(item['category'])}',
            ),
            Text('المحافظة: ${item['governorate'] ?? ''}'),
            if ((item['description']?.toString().trim() ?? '').isNotEmpty)
              Text(
                item['description'].toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
    'in_progress' => 'قيد التنفيذ',
    'closed' => 'مغلق',
    _ => 'قيد الانتظار',
  };

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
