import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../core/layout/app_responsive.dart';
import '../../../core/theme/app_colors.dart';

import '../../../core/widgets/app_brand_mark.dart';

import '../../../routing/app_routes.dart';

import '../../properties/data/parcel_properties_provider.dart';

import '../../properties/presentation/property_card.dart';

class ParcelProfileScreen extends ConsumerStatefulWidget {
  const ParcelProfileScreen({
    super.key,

    required this.parcelId,

    required this.title,

    this.expectedPostsCount,
  });

  final String parcelId;

  final String title;

  final int? expectedPostsCount;

  @override
  ConsumerState<ParcelProfileScreen> createState() =>
      _ParcelProfileScreenState();
}

class _ParcelProfileScreenState extends ConsumerState<ParcelProfileScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(parcelPropertiesProvider(widget.parcelId));
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(parcelPropertiesProvider(widget.parcelId));

    await ref.read(parcelPropertiesProvider(widget.parcelId).future);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(parcelPropertiesProvider(widget.parcelId));

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,

      appBar: AppBar(title: AppBarBrandTitle(widget.title)),

      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                Icon(Icons.wifi_off_rounded, size: 48, color: scheme.primary),

                const SizedBox(height: 12),

                Text(
                  'تعذر تحميل المنشورات',

                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,

                    color: AppColors.brandPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                Text('$e', textAlign: TextAlign.center),

                const SizedBox(height: 16),

                FilledButton.icon(
                  onPressed: _refresh,

                  icon: const Icon(Icons.refresh_rounded),

                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),

        data: (items) {
          final countLabel = items.isNotEmpty
              ? '${items.length}'
              : (widget.expectedPostsCount != null &&
                        widget.expectedPostsCount! > 0
                    ? '${widget.expectedPostsCount} (جاري التحديث)'
                    : '0');

          return RefreshIndicator(
            onRefresh: _refresh,

            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: AppResponsive.pagePadding(
                context,
                top: 8,
                accountForShellNav: true,
              ),

              children: [
                Card(
                  margin: const EdgeInsets.only(bottom: 16),

                  child: Padding(
                    padding: const EdgeInsets.all(14),

                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        CircleAvatar(
                          radius: 36,

                          backgroundColor: scheme.primary.withValues(
                            alpha: 0.12,
                          ),

                          child: Icon(
                            Icons.grid_view_rounded,

                            color: scheme.primary,

                            size: 30,
                          ),
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              Text(
                                widget.title,

                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                'عدد المنشورات: $countLabel',

                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: scheme.primary,

                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),

                    child: Center(
                      child: Text(
                        widget.expectedPostsCount != null &&
                                widget.expectedPostsCount! > 0
                            ? 'المنشورات قيد المراجعة أو لم تُزامَن بعد. اسحب للتحديث.'
                            : 'لا توجد منشورات لهذه المقاطعة بعد.',

                        textAlign: TextAlign.center,

                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  for (final p in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        height: 270,
                        child: PropertyCard(
                          property: p,
                          onTap: () => context.push(
                            '${AppRoutes.propertyDetails}/${p.id}',
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}
