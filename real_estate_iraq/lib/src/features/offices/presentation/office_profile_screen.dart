import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_brand_mark.dart';
import '../../../core/api/api_providers.dart';
import '../../../routing/app_routes.dart';
import '../data/offices_providers.dart';
import '../../properties/data/office_properties_provider.dart';
import '../../properties/presentation/property_card.dart';

final officeReelsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, officeId) async {
  final data = await ref
      .read(vewoApiClientProvider)
      .getJson('reels/list', query: {'owner_id': officeId, 'limit': '20'});
  final raw = data['items'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
});

class OfficeProfileScreen extends ConsumerWidget {
  const OfficeProfileScreen({super.key, required this.officeId});

  final String officeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(officeDetailProvider(officeId));
    final propsAsync = ref.watch(officePropertiesProvider(officeId));
    final reelsAsync = ref.watch(officeReelsProvider(officeId));
    final title = detailAsync.valueOrNull?.displayName ?? 'منشورات المكتب';

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: AppBarBrandTitle(title),
      ),
      body: propsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('تعذر تحميل الإعلانات')),
        data: (items) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              detailAsync.when(
                data: (d) {
                  if (d == null) return const SizedBox.shrink();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (d.photoUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: CachedNetworkImage(
                                  imageUrl: d.photoUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => const Icon(Icons.apartment_rounded),
                                ),
                              ),
                            )
                          else
                            CircleAvatar(
                              radius: 36,
                              child: Icon(Icons.apartment_rounded,
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        d.displayName,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ),
                                    if (d.officeVerified)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Icon(
                                          Icons.verified_rounded,
                                          color: Theme.of(context).colorScheme.primary,
                                          size: 22,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(d.phone, textDirection: TextDirection.ltr),
                                if (d.address.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    d.address,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              reelsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(),
                ),
                error: (_, _) => const SizedBox.shrink(),
                data: (reels) {
                  if (reels.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ريلز المكتب',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 136,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: reels.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final r = reels[index];
                            final caption = (r['caption']?.toString() ?? '').trim();
                            return InkWell(
                              onTap: () => context.push(AppRoutes.reels),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 110,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    const Center(
                                      child: Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: Colors.white,
                                        size: 42,
                                      ),
                                    ),
                                    Positioned(
                                      left: 8,
                                      right: 8,
                                      bottom: 8,
                                      child: Text(
                                        caption.isEmpty ? 'ريل عقاري' : caption,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  );
                },
              ),
              Text(
                'منشورات المكتب',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(child: Text('لا توجد منشورات معتمدة لهذا المكتب بعد.')),
                )
              else
                ...items.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      height: 270,
                      child: PropertyCard(
                        property: p,
                        onTap: () => context.push('${AppRoutes.propertyDetails}/${p.id}'),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
