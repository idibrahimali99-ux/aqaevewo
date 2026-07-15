import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';

/// بطاقة سياق الريل أعلى المحادثة عند التواصل من قسم الريلز.
class ReelContextBanner extends StatefulWidget {
  const ReelContextBanner({super.key, required this.reel});

  final Map<String, dynamic> reel;

  @override
  State<ReelContextBanner> createState() => _ReelContextBannerState();
}

class _ReelContextBannerState extends State<ReelContextBanner> {
  VideoPlayerController? _vc;

  @override
  void initState() {
    super.initState();
    final url = widget.reel['video_public_url']?.toString() ?? '';
    if (url.isNotEmpty) {
      _vc = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = widget.reel['caption']?.toString().trim() ?? '';
    final publisher = widget.reel['publisher_display']?.toString().trim() ?? '';
    final propertyId = widget.reel['property_id']?.toString().trim();
    final reelId = widget.reel['id']?.toString() ?? '';
    final ownerId = widget.reel['owner_user_id']?.toString().trim() ?? '';
    final shortReelId = reelId.length > 8 ? reelId.substring(0, 8) : reelId;
    final shortPropertyId = propertyId != null && propertyId.length > 8
        ? propertyId.substring(0, 8)
        : propertyId;

    void openLinked() {
      if (reelId.isNotEmpty) {
        context.go(_reelRoute(reelId: reelId, ownerId: ownerId));
        return;
      }
      if (propertyId != null && propertyId.isNotEmpty) {
        context.push('${AppRoutes.propertyDetails}/$propertyId');
      }
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: openLinked,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 96,
                  child: _vc != null && _vc!.value.isInitialized
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _vc!.value.size.width,
                            height: _vc!.value.size.height,
                            child: VideoPlayer(_vc!),
                          ),
                        )
                      : ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.play_circle_outline_rounded,
                            color: scheme.primary,
                            size: 36,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          height: 18,
                          width: 56,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AppBrandMark(
                              variant: AppBrandMarkVariant.compact,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'جاءت الرسالة من هذا الريلز',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: scheme.primary,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (publisher.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        publisher,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        if (shortReelId.isNotEmpty)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('ريل: $shortReelId'),
                          ),
                        if (shortPropertyId != null &&
                            shortPropertyId.isNotEmpty)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('منشور: $shortPropertyId'),
                          ),
                      ],
                    ),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (propertyId != null && propertyId.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => context.push(
                              '${AppRoutes.propertyDetails}/$propertyId',
                            ),
                            icon: const Icon(
                              Icons.home_work_outlined,
                              size: 18,
                            ),
                            label: const Text('فتح المنشور'),
                          ),
                        if (reelId.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => context.go(
                              _reelRoute(reelId: reelId, ownerId: ownerId),
                            ),
                            icon: const Icon(
                              Icons.video_collection_outlined,
                              size: 18,
                            ),
                            label: const Text('فتح الريل'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _reelRoute({required String reelId, required String ownerId}) {
    return Uri(
      path: AppRoutes.reels,
      queryParameters: {
        'reel_id': reelId,
        if (ownerId.isNotEmpty) 'owner_id': ownerId,
      },
    ).toString();
  }
}
