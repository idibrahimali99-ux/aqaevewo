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
    this.onRejectedEdit,
  });

  final List<Property> items;
  final bool showPublisherModeration;
  final bool viewerIsOffice;
  final void Function(Property property)? onRejectedEdit;

  @override
  Widget build(BuildContext context) {
    final extraFooter = showPublisherModeration && onRejectedEdit != null;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
        mainAxisExtent: extraFooter ? 368 : 318,
      ),
      itemBuilder: (context, index) {
        final p = items[index];
        final showEdit =
            extraFooter &&
            p.approvalStatus == 'rejected' &&
            p.resubmissionAllowed;
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
            if (showEdit) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: FilledButton.tonal(
                  onPressed: () => onRejectedEdit!(p),
                  child: const Text('تعديل وإعادة إرسال'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
