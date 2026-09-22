import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_responsive.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';
import '../../favorites/data/favorites_controller.dart';
import '../../properties/data/properties_providers.dart';
import '../../properties/presentation/property_card.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favIds = ref.watch(favoritesControllerProvider);
    final all = ref.watch(allPropertiesProvider);
    final loading = ref.watch(propertyListingsLoadingProvider);
    final items = all.where((p) => favIds.contains(p.id)).toList();

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const AppBarBrandTitle('المحفوظات')),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(propertyListingsProvider.notifier).reload();
        },
        child: loading && items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 180),
                Center(child: CircularProgressIndicator()),
              ],
            )
          : items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 180),
                Center(child: Text('لا توجد منشورات محفوظة بعد')),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppResponsive.pagePadding(
                context,
                accountForShellNav: true,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final p = items[i];
                return PropertyCard(
                  property: p,
                  onTap: () =>
                      context.push('${AppRoutes.propertyDetails}/${p.id}'),
                );
              },
            ),
      ),
    );
  }
}
