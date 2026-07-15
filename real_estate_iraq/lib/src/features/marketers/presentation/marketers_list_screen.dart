import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_responsive.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';
import '../data/marketers_providers.dart';

class MarketersListScreen extends ConsumerWidget {
  const MarketersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(approvedMarketersProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const AppBarBrandTitle('المسوقون العقاريون')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('تعذر تحميل المسوقين')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'لا يوجد مسوقون معتمدون حالياً.',
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
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final marketer = items[i];
              final hasPhoto = marketer.photoUrl.isNotEmpty;
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
                        ? CachedNetworkImageProvider(marketer.photoUrl)
                        : null,
                    child: hasPhoto
                        ? null
                        : Icon(
                            Icons.person_pin_circle_rounded,
                            color: scheme.primary,
                          ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          marketer.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (marketer.verified)
                        Icon(
                          Icons.verified_rounded,
                          color: scheme.primary,
                          size: 22,
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('مسوق عقاري'),
                      Text(marketer.phone, textDirection: TextDirection.ltr),
                      if (marketer.address.isNotEmpty)
                        Text(
                          marketer.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => context.push(
                    '${AppRoutes.marketerProfile}/${marketer.id}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
