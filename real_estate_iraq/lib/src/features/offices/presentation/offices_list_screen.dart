import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';
import '../data/offices_providers.dart';

class OfficesListScreen extends ConsumerWidget {
  const OfficesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(approvedOfficesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const AppBarBrandTitle('مكاتب عقارية'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('تعذر تحميل المكاتب')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'لا توجد مكاتب معتمدة حالياً.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final o = items[i];
              final hasPhoto = o.photoUrl.isNotEmpty;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: hasPhoto ? CachedNetworkImageProvider(o.photoUrl) : null,
                    child: hasPhoto
                        ? null
                        : Icon(Icons.apartment_rounded, color: Theme.of(context).colorScheme.primary),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (o.officeVerified)
                        Icon(
                          Icons.verified_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.phone, textDirection: TextDirection.ltr),
                      if (o.address.isNotEmpty)
                        Text(
                          o.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  isThreeLine: o.address.isNotEmpty,
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => context.push('${AppRoutes.officeProfile}/${o.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
