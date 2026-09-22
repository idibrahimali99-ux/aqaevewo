import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/app_routes.dart';
import '../domain/property.dart';
import 'property_card.dart';

class PropertyCardsGrid extends StatelessWidget {
  const PropertyCardsGrid({
    super.key,
    required this.items,
    this.showPublisherModeration = false,
    this.viewerIsOffice = false,
    this.onEdit,
    this.onDelete,
  });

  final List<Property> items;
  final bool showPublisherModeration;
  final bool viewerIsOffice;
  final void Function(Property property)? onEdit;
  final void Function(Property property)? onDelete;

  @override
  Widget build(BuildContext context) {
    final extraFooter =
        showPublisherModeration && (onEdit != null || onDelete != null);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
        mainAxisExtent: extraFooter ? 408 : 318,
      ),
      itemBuilder: (context, index) {
        final p = items[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PropertyCard(
                property: p,
                showMapPreview: false,
                showPublisherModeration: showPublisherModeration,
                viewerIsOffice: viewerIsOffice,
                onTap: () =>
                    context.push('${AppRoutes.propertyDetails}/${p.id}'),
              ),
            ),
            if (extraFooter) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (onEdit != null)
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: FilledButton.tonal(
                          onPressed: () => onEdit!(p),
                          child: const Text('تعديل'),
                        ),
                      ),
                    ),
                  if (onEdit != null && onDelete != null)
                    const SizedBox(width: 6),
                  if (onDelete != null)
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () => onDelete!(p),
                          child: const Text('حذف'),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
