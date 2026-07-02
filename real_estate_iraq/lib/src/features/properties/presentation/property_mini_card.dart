import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:vewo_shared/vewo_shared.dart' show IQDFormatter;
import '../../../core/theme/app_colors.dart';
import '../domain/property.dart';

/// بطاقة مصغّرة لقائمة «منشوراتي».
class PropertyMiniCard extends StatelessWidget {
  const PropertyMiniCard({
    super.key,
    required this.property,
    this.onTap,
    this.showModeration = false,
  });

  final Property property;
  final VoidCallback? onTap;
  final bool showModeration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = property.images.isNotEmpty ? property.images.first : '';
    final price = property.priceIqd <= 0
        ? 'حسب الاتفاق'
        : IQDFormatter.format(property.priceIqd);

    String? statusLabel;
    Color? statusColor;
    if (showModeration) {
      if (property.isSold) {
        statusLabel = 'تم البيع';
        statusColor = scheme.primary;
      } else if (property.approvalStatus == 'rejected') {
        statusLabel = 'مرفوض';
        statusColor = scheme.error;
      } else if (!property.isApproved || property.approvalStatus == 'pending') {
        statusLabel = 'قيد المراجعة';
        statusColor = AppColors.warningLight;
      }
    }

    return Material(
      color: scheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 96,
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: thumb.isEmpty
                    ? ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    : CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.title.trim().isNotEmpty
                            ? property.title.trim()
                            : property.displayCategoryAr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: scheme.primary,
                        ),
                      ),
                      if (property.areaSqm > 1)
                        Text(
                          '${property.areaSqm} م²',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      if (statusLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
