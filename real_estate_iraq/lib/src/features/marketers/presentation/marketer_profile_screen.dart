import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/contact/property_contact.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/layout/app_responsive.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';
import '../../properties/data/office_properties_provider.dart';
import '../../properties/presentation/property_card.dart';
import '../data/marketers_providers.dart';

final marketerReelsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, marketerId) async {
      final data = await ref
          .read(vewoApiClientProvider)
          .getJson(
            'reels/list',
            query: {'owner_id': marketerId, 'limit': '20'},
          );
      final raw = data['items'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    });

class MarketerProfileScreen extends ConsumerWidget {
  const MarketerProfileScreen({super.key, required this.marketerId});

  final String marketerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(marketerDetailProvider(marketerId));
    final propsAsync = ref.watch(officePropertiesProvider(marketerId));
    final reelsAsync = ref.watch(marketerReelsProvider(marketerId));
    final title = detailAsync.valueOrNull?.displayName ?? 'صفحة المسوق';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: AppBarBrandTitle(title)),
      body: propsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('تعذر تحميل منشورات المسوق')),
        data: (items) {
          return ListView(
            padding: AppResponsive.pagePadding(
              context,
              top: 8,
              accountForShellNav: true,
            ),
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
                                  errorWidget: (_, _, _) => const Icon(
                                    Icons.person_pin_circle_rounded,
                                  ),
                                ),
                              ),
                            )
                          else
                            CircleAvatar(
                              radius: 36,
                              child: Icon(
                                Icons.person_pin_circle_rounded,
                                color: scheme.primary,
                              ),
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ),
                                    if (d.verified)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4,
                                        ),
                                        child: Icon(
                                          Icons.verified_rounded,
                                          color: scheme.primary,
                                          size: 22,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'مسوق عقاري',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(d.phone, textDirection: TextDirection.ltr),
                                if (d.address.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    d.address,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(height: 1.4),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: d.phone.trim().isEmpty
                                            ? null
                                            : () async {
                                                final raw = d.phone.replaceAll(
                                                  RegExp(r'[^\d+]'),
                                                  '',
                                                );
                                                if (raw.isEmpty) return;
                                                await launchUrl(
                                                  Uri.parse('tel:$raw'),
                                                  mode: LaunchMode
                                                      .externalApplication,
                                                );
                                              },
                                        icon: const Icon(Icons.call_rounded),
                                        label: const Text('اتصال'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: d.phone.trim().isEmpty
                                            ? null
                                            : () async {
                                                await openWhatsAppToPhone(
                                                  d.phone,
                                                  message:
                                                      'مرحباً، أتواصل معكم بخصوص منشورات ${d.displayName}',
                                                );
                                              },
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF25D366),
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.chat_rounded),
                                        label: const Text('واتساب'),
                                      ),
                                    ),
                                  ],
                                ),
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
                        'ريلز المسوق',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 136,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: reels.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final r = reels[index];
                            final caption = (r['caption']?.toString() ?? '')
                                .trim();
                            final reelId = r['id']?.toString() ?? '';
                            return InkWell(
                              onTap: () {
                                final query =
                                    {
                                          'owner_id': marketerId,
                                          if (reelId.isNotEmpty)
                                            'reel_id': reelId,
                                        }.entries
                                        .map(
                                          (e) =>
                                              '${e.key}=${Uri.encodeComponent(e.value)}',
                                        )
                                        .join('&');
                                context.push('${AppRoutes.reels}?$query');
                              },
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
                'منشورات المسوق',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: Center(
                    child: Text('لا توجد منشورات معتمدة لهذا المسوق بعد.'),
                  ),
                )
              else
                ...items.map(
                  (p) => Padding(
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
                ),
            ],
          );
        },
      ),
    );
  }
}
