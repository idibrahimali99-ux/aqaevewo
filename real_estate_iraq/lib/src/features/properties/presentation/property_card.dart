import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:vewo_shared/vewo_shared.dart' show IQDFormatter;
import '../../../core/api/api_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/property_image_gallery.dart';
import '../../../core/widgets/property_video_player.dart';
import '../domain/property.dart';
import '../domain/property_category.dart';
import '../domain/property_segment.dart';
import '../../favorites/data/favorites_controller.dart';

IconData _propertyCategoryIcon(PropertyCategory c) => switch (c) {
  PropertyCategory.land => Icons.landscape_outlined,
  PropertyCategory.house => Icons.home_work_outlined,
  PropertyCategory.apartment => Icons.apartment_outlined,
  PropertyCategory.shop => Icons.storefront_outlined,
  PropertyCategory.compound => Icons.domain_outlined,
  PropertyCategory.villa => Icons.villa_outlined,
};

class PropertyCard extends ConsumerWidget {
  const PropertyCard({
    super.key,
    required this.property,
    this.onTap,
    this.showMapPreview = true,
    this.showPublisherModeration = false,
    this.viewerIsOffice = false,
  });

  final Property property;
  final VoidCallback? onTap;
  final bool showMapPreview;

  /// في «منشوراتي / إعلاناتي» فقط — شارات المراجعة والرفض.
  final bool showPublisherModeration;

  /// صاحب الملف مكتب: لا يُعرض سبب الرفض التفصيلي (يظهر للزبون فقط).
  final bool viewerIsOffice;

  bool get _negotiableFlag {
    final d = property.detailsJson;
    if (d == null) return false;
    final v = d['negotiable'];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }
    return false;
  }

  bool get _hideCompactArea =>
      property.segment == PropertySegment.parcel && property.areaSqm <= 1;

  String? get _publishedLabel {
    final t = property.publishedAt;
    if (t == null) return null;
    return DateFormat('yyyy-MM-dd', 'en').format(t.toLocal());
  }

  String? get _rejectionNote {
    final d = property.detailsJson;
    if (d == null) return null;
    for (final k in const [
      'rejection_reason',
      'moderation_note',
      'admin_note',
      'reject_reason',
    ]) {
      final v = d[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  bool get _showRejectedStrip =>
      showPublisherModeration &&
      !property.isSold &&
      property.approvalStatus == 'rejected';

  bool get _showPendingStrip =>
      showPublisherModeration &&
      !property.isSold &&
      property.approvalStatus != 'rejected' &&
      (!property.isApproved || property.approvalStatus == 'pending');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final savedIds = ref.watch(favoritesControllerProvider);
    final isSaved = savedIds.contains(property.id);
    final loc =
        '${property.governorate}${property.addressLine.trim().isEmpty ? '' : ' • ${property.addressLine.trim()}'}';
    final compoundName =
        (property.compoundName ??
                property.detailsJson?['compound_name']?.toString())
            ?.trim();
    final purposeAr = property.purpose == 'rent' ? 'للإيجار' : 'للبيع';
    final priceLabel = property.priceIqd > 0
        ? IQDFormatter.format(property.priceIqd)
        : 'حسب الاتفاق';
    const border = AppColors.cardBorder;
    Future<void> shareProperty() async {
      final link = Uri.parse('${ApiConfig.baseUrl}/index.php')
          .replace(queryParameters: {'r': 'properties/get', 'id': property.id})
          .toString();
      final text = [
        property.title.trim().isEmpty
            ? property.displayCategoryAr
            : property.title.trim(),
        if (property.publicNo != null) 'رقم المنشور: #${property.publicNo}',
        link,
      ].join('\n');
      await SharePlus.instance.share(
        ShareParams(text: text, subject: property.title.trim()),
      );
    }

    Future<void> toggleSaved() async {
      final messenger = ScaffoldMessenger.maybeOf(context);
      await ref.read(favoritesControllerProvider.notifier).toggle(property.id);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            isSaved ? 'تمت الإزالة من المحفوظات' : 'تم الحفظ في المحفوظات',
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.74,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PropertyImagesPager(
                    imageUrls: property.images,
                    videoUrl: property.videoUrl,
                    videoTrimStartSeconds: property.videoTrimStartSeconds,
                    videoTrimEndSeconds: property.videoTrimEndSeconds,
                    propertyCode: property.publicNo,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.18),
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    top: 10,
                    end: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.frameGold.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        child: Text(
                          purposeAr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (property.publicNo != null)
                    Positioned.directional(
                      textDirection: Directionality.of(context),
                      top: 8,
                      start: 8,
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: '#${property.publicNo}'),
                          );
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            const SnackBar(content: Text('تم نسخ رقم المنشور')),
                          );
                        },
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.56),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '#${property.publicNo}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.copy_rounded,
                                  color: Colors.white70,
                                  size: 15,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_showPendingStrip)
                    Positioned.directional(
                      textDirection: Directionality.of(context),
                      top: 62,
                      end: 14,
                      child: Material(
                        color: AppColors.warningLight.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            'قيد المراجعة',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_showRejectedStrip)
                    Positioned.directional(
                      textDirection: Directionality.of(context),
                      top: 62,
                      end: 14,
                      child: Material(
                        color: scheme.error.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            'مرفوض',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (property.isSold)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        color: scheme.primary,
                        child: const Text(
                          'تم البيع',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        flex: 5,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.frameGold.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              priceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.frameGold,
                                    letterSpacing: -0.3,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: Text(
                          property.title.trim().isNotEmpty
                              ? property.title.trim()
                              : property.displayCategoryAr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (_negotiableFlag && property.priceIqd > 0) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _SoftPill(
                        icon: Icons.handshake_outlined,
                        label: 'قابل للتفاوض',
                        color: AppColors.frameGold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 19,
                        color: AppColors.mapPin,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          loc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.dataText,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (compoundName != null && compoundName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _SoftPill(
                        icon: Icons.location_city_outlined,
                        label: compoundName,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ],
                  if (_publishedLabel != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _publishedLabel!,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.dataText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Divider(height: 1, color: border),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_hideCompactArea)
                        _PropertyMainStat(
                          icon: Icons.grid_view_rounded,
                          value: '${property.areaSqm} م²',
                          label: 'المساحة',
                          color: AppColors.frameGold,
                        )
                      else
                        _PropertyMainStat(
                          icon: _propertyCategoryIcon(property.category),
                          value: property.displayCategoryAr,
                          label: 'القسم',
                          color: AppColors.frameGold,
                        ),
                    ],
                  ),
                  if (property.publisherLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          property.publisherVerified
                              ? Icons.verified_rounded
                              : Icons.person_outline_rounded,
                          size: 16,
                          color: property.publisherVerified
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            property.publisherLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _PropertyInlineAction(
                          icon: Icons.ios_share_rounded,
                          label: 'مشاركة',
                          tooltip: 'مشاركة',
                          onTap: shareProperty,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PropertyInlineAction(
                          icon: isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          label: isSaved ? 'محفوظ' : 'حفظ',
                          tooltip: isSaved ? 'إزالة من المحفوظات' : 'حفظ',
                          selected: isSaved,
                          onTap: () {
                            toggleSaved();
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_showRejectedStrip &&
                      !viewerIsOffice &&
                      (_rejectionNote ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _rejectionNote ?? '',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyInlineAction extends StatelessWidget {
  const _PropertyInlineAction({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = Tooltip(
      message: tooltip,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.frameGold.withValues(alpha: 0.16)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.frameGold.withValues(alpha: 0.5)
                : AppColors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.frameGold : AppColors.textPrimary,
              size: 17,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? AppColors.frameGold : AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: child,
    );
  }
}

class _PropertyMainStat extends StatelessWidget {
  const _PropertyMainStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SoftPill extends StatelessWidget {
  const _SoftPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyImagesPager extends StatefulWidget {
  const _PropertyImagesPager({
    required this.imageUrls,
    this.videoUrl,
    this.videoTrimStartSeconds,
    this.videoTrimEndSeconds,
    this.propertyCode,
  });

  final List<String> imageUrls;
  final String? videoUrl;
  final int? videoTrimStartSeconds;
  final int? videoTrimEndSeconds;
  final int? propertyCode;

  @override
  State<_PropertyImagesPager> createState() => _PropertyImagesPagerState();
}

class _PropertyImagesPagerState extends State<_PropertyImagesPager> {
  late final PageController _page;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _page = PageController();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final urls = widget.imageUrls.where((u) => u.trim().isNotEmpty).toList();
    final videoUrl = widget.videoUrl?.trim();
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final itemCount = urls.length + (hasVideo ? 1 : 0);
    if (itemCount == 0) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: scheme.outline,
          size: 40,
        ),
      );
    }
    Widget videoTile() {
      return Stack(
        fit: StackFit.expand,
        children: [
          PropertyVideoPlayer(
            url: videoUrl!,
            trimStartSeconds: widget.videoTrimStartSeconds,
            trimEndSeconds: widget.videoTrimEndSeconds,
          ),
          Positioned(
            top: 10,
            right: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text('فيديو', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget imageAt(int i) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: urls[i],
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              color: scheme.surfaceContainerHighest,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              ),
            ),
            errorWidget: (_, _, _) => Container(
              color: scheme.surfaceContainerHighest,
              child: Icon(
                Icons.image_not_supported_outlined,
                color: scheme.outline,
              ),
            ),
          ),
        ],
      );
    }

    if (itemCount == 1) {
      if (hasVideo) return videoTile();
      return GestureDetector(
        onTap: () => showPropertyImageGallery(
          context,
          imageUrls: urls,
          propertyCode: widget.propertyCode,
        ),
        child: imageAt(0),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _page,
          itemCount: itemCount,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            if (hasVideo && i == 0) {
              return videoTile();
            }
            final imageIndex = hasVideo ? i - 1 : i;
            return GestureDetector(
              onTap: () => showPropertyImageGallery(
                context,
                imageUrls: urls,
                initialIndex: imageIndex,
                propertyCode: widget.propertyCode,
              ),
              child: imageAt(imageIndex),
            );
          },
        ),
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(itemCount, (i) {
              final on = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: on ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: on
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
