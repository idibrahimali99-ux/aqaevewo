import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';
import '../../properties/data/compound_properties_provider.dart';
import '../../properties/presentation/property_card.dart';

class CompoundProfileScreen extends ConsumerStatefulWidget {
  const CompoundProfileScreen({
    super.key,
    required this.compoundId,
    required this.title,
    this.expectedPostsCount,
  });

  final String compoundId;
  final String title;
  final int? expectedPostsCount;

  @override
  ConsumerState<CompoundProfileScreen> createState() =>
      _CompoundProfileScreenState();
}

class _CompoundProfileScreenState extends ConsumerState<CompoundProfileScreen> {
  ({String compoundId, String title}) get _scope =>
      (compoundId: widget.compoundId, title: widget.title);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(compoundPropertiesByTitleProvider(_scope));
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(compoundPropertiesByTitleProvider(_scope));
    await ref.read(compoundPropertiesByTitleProvider(_scope).future);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(compoundPropertiesByTitleProvider(_scope));
    final scheme = Theme.of(context).colorScheme;
    final items = async.valueOrNull ?? const [];
    final isLoading = async.isLoading && items.isEmpty;
    final error = async.hasError ? async.error : null;
    final countLabel = items.isNotEmpty
        ? '${items.length}'
        : (widget.expectedPostsCount != null && widget.expectedPostsCount! > 0
              ? '${widget.expectedPostsCount} (جاري التحديث)'
              : '0');

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: AppBarBrandTitle(widget.title)),
      body: RefreshIndicator(
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
                      backgroundColor: scheme.primary.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.location_city_rounded,
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
                                  color: AppColors.brandPrimary,
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
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 48,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'تعذر تحميل المنشورات',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandPrimary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text('$error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(
                  child: Text(
                    widget.expectedPostsCount != null &&
                            widget.expectedPostsCount! > 0
                        ? 'المنشورات قيد المراجعة أو لم تُزامَن بعد. اسحب للتحديث.'
                        : 'لا توجد منشورات لهذا المجمع بعد.',
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
                  child: PropertyCard(
                    property: p,
                    onTap: () =>
                        context.push('${AppRoutes.propertyDetails}/${p.id}'),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
