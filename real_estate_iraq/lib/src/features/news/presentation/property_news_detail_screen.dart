import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_brand_mark.dart';
import '../data/property_news_detail_provider.dart';
import '../domain/property_news_models.dart';

/// عرض خبر عقاري كمنشور واضح (صورة، عنوان، تاريخ، نص كامل).
class PropertyNewsDetailScreen extends ConsumerWidget {
  const PropertyNewsDetailScreen({super.key, required this.newsId});

  final String newsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(propertyNewsDetailProvider(newsId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('تعذر تحميل الخبر', style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        data: (detail) {
          if (detail == null) {
            return Center(
              child: Text('الخبر غير موجود', style: Theme.of(context).textTheme.titleMedium),
            );
          }
          final dateStr = formatPropertyNewsDate(detail.publishedAt);

          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                pinned: true,
                title: const SliverAppBarBrandHeading(screenTitle: 'خبر عقاري'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: CachedNetworkImage(
                            imageUrl: detail.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (_, _, _) => ColoredBox(
                              color: scheme.surfaceContainerHighest,
                              child: Icon(Icons.broken_image_outlined,
                                  size: 48, color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        detail.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 18, color: scheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.65),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                          child: SelectableText(
                            detail.body,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  height: 1.75,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ),
                    ],
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
