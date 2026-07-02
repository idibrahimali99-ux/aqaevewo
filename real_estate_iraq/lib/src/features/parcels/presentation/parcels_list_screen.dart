import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vewo_shared/vewo_shared.dart' show Iraq;
import '../../../core/governorates/governorates_provider.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';
import '../../offices/data/offices_providers.dart';

class ParcelsListScreen extends ConsumerStatefulWidget {
  const ParcelsListScreen({super.key});

  @override
  ConsumerState<ParcelsListScreen> createState() => _ParcelsListScreenState();
}

class _ParcelsListScreenState extends ConsumerState<ParcelsListScreen> {
  String? _gov;
  final _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(parcelsListProvider);
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parcelsAsync = ref.watch(parcelsListProvider);
    final govs = ref.watch(governoratesProvider).valueOrNull ?? Iraq.governorates;

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const AppBarBrandTitle('المقاطعات')),
      body: parcelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('تعذر تحميل قائمة المقاطعات')),
        data: (parcels) {
          final q = _q.text.trim().toLowerCase();
          final filtered = parcels.where((p) {
            if (_gov != null && _gov!.trim().isNotEmpty) {
              if (p.governorate.trim() != _gov!.trim()) return false;
            }
            if (q.isNotEmpty) {
              final hay =
                  '${p.displayName} ${p.governorate} ${p.districtName ?? ''}'
                      .toLowerCase();
              if (!hay.contains(q)) return false;
            }
            return true;
          }).toList();

          final groups = <String, List<ParcelSummary>>{};
          for (final p in filtered) {
            final g = p.governorate.trim().isEmpty ? 'بدون محافظة' : p.governorate.trim();
            (groups[g] ??= <ParcelSummary>[]).add(p);
          }
          final orderedGovs = [
            ...govs.where(groups.containsKey),
            ...groups.keys.where((g) => !govs.contains(g)).toList()..sort(),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text(
                'اختر مقاطعة لعرض منشوراتها — تُدار المقاطعات من لوحة الإدارة.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم المقاطعة أو المحافظة…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _q.text.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'مسح',
                          onPressed: () {
                            _q.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: ValueKey<String?>(_gov),
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
                    (g) => DropdownMenuItem<String?>(value: g, child: Text(g)),
                  ),
                ],
                onChanged: (v) => setState(() => _gov = v),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'جميع المقاطعات',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Text(
                    '${filtered.length}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      parcels.isEmpty
                          ? 'لا توجد مقاطعات متاحة حالياً.'
                          : 'لا توجد نتائج مطابقة للبحث/الفلتر.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.black45),
                    ),
                  ),
                )
              else
                for (final gov in orderedGovs) ...[
                  if ((groups[gov] ?? const []).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 10),
                      child: Text(
                        gov,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                      ),
                    ),
                    for (final parcel in (groups[gov] ?? const []))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.grid_view_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              parcel.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(parcel.governorate),
                                Text(
                                  'المنشورات: ${parcel.postsCount}',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_left_rounded),
                            onTap: () {
                              final title =
                                  Uri.encodeComponent(parcel.displayName);
                              context.push(
                                '${AppRoutes.parcelProfile}/${parcel.id}?title=$title&posts=${parcel.postsCount}',
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ],
            ],
          );
        },
      ),
    );
  }
}
