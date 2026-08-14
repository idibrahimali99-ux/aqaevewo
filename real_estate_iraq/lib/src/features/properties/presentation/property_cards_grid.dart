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
  });

  final List<Property> items;
  final bool showPublisherModeration;
  final bool viewerIsOffice;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
        mainAxisExtent: 318,
      ),
      itemBuilder: (context, index) {
        final p = items[index];
        return PropertyCard(
          property: p,
          showMapPreview: false,
          showPublisherModeration: showPublisherModeration,
          viewerIsOffice: viewerIsOffice,
          onTap: () => context.push('${AppRoutes.propertyDetails}/${p.id}'),
        );
      },
    );
  }
}
