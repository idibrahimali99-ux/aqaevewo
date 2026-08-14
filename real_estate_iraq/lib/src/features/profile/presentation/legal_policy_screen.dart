import 'package:flutter/material.dart';

import '../../../core/layout/app_responsive.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../data/aqar_town_legal.dart';

enum AqarTownLegalKind { privacy, terms }

class LegalPolicyScreen extends StatelessWidget {
  const LegalPolicyScreen({super.key, required this.kind});

  final AqarTownLegalKind kind;

  @override
  Widget build(BuildContext context) {
    final isPrivacy = kind == AqarTownLegalKind.privacy;
    final title = isPrivacy
        ? AqarTownLegal.privacyTitle
        : AqarTownLegal.termsTitle;
    final intro = isPrivacy
        ? AqarTownLegal.privacyIntro
        : AqarTownLegal.termsIntro;
    final sections = isPrivacy
        ? AqarTownLegal.privacySections
        : AqarTownLegal.termsSections;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: AppBarBrandTitle(title)),
      body: ListView(
        padding: AppResponsive.pagePadding(context, accountForShellNav: true),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppBrandMark(variant: AppBrandMarkVariant.compact),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'آخر تحديث: ${AqarTownLegal.lastUpdated}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(intro, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final section in sections) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      section.body,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.55,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
