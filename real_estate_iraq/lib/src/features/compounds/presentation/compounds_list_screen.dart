import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vewo_shared/vewo_shared.dart' show Iraq;
import '../../../core/governorates/governorates_provider.dart';
import '../../../core/layout/app_responsive.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';
import '../../offices/data/offices_providers.dart';

/// قائمة المجمعات السكنية — نفس أسلوب عرض «المكاتب».
class CompoundsListScreen extends ConsumerStatefulWidget {
  const CompoundsListScreen({super.key});

  @override
  ConsumerState<CompoundsListScreen> createState() =>
      _CompoundsListScreenState();
}

class _CompoundsListScreenState extends ConsumerState<CompoundsListScreen> {
  final _q = TextEditingController();
  String? _gov;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(compoundsListProvider);
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(compoundsListProvider);
    final govs =
        ref.watch(governoratesProvider).valueOrNull ?? Iraq.governorates;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const AppBarBrandTitle('مجمعات سكنية')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('تعذر تحميل المجمعات')),
        data: (items) {
          final q = _q.text.trim().toLowerCase();
          final visible = items.where((c) {
            if (_gov != null && c.governorate.trim() != _gov) return false;
            if (q.isEmpty) return true;
            final hay =
                '${c.displayName} ${c.governorate} ${c.districtName ?? ''}'
                    .toLowerCase();
            return hay.contains(q);
          }).toList();
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'لا توجد مجمعات مفعّلة حالياً.\nتُضاف من لوحة الإدارة.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: AppResponsive.pagePadding(
              context,
              accountForShellNav: true,
            ),
            itemCount: visible.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(
                  children: [
                    TextField(
                      controller: _q,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'ابحث باسم المجمع أو القضاء / الناحية…',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: _gov,
                      decoration: const InputDecoration(
                        labelText: 'المحافظة',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('الكل'),
                        ),
                        ...govs.map(
                          (g) => DropdownMenuItem<String?>(
                            value: g,
                            child: Text(g),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _gov = v),
                    ),
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'لا توجد مجمعات مطابقة للبحث.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                  ],
                );
              }
              final c = visible[i - 1];
              final hasPhoto = c.photoUrl.trim().isNotEmpty;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primaryContainer,
                    backgroundImage: hasPhoto
                        ? CachedNetworkImageProvider(c.photoUrl)
                        : null,
                    child: hasPhoto
                        ? null
                        : Icon(
                            Icons.location_city_rounded,
                            color: scheme.primary,
                          ),
                  ),
                  title: Text(
                    c.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.governorate,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'المنشورات: ${c.postsCount}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () {
                    final title = Uri.encodeComponent(c.displayName);
                    context.push(
                      '${AppRoutes.compoundProfile}/${c.id}?title=$title&posts=${c.postsCount}',
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
