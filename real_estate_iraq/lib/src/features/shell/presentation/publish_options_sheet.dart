import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shape.dart';

/// قائمة منبثقة: نشر عقار أو نشر ريلز.
Future<void> showPublishOptionsSheet(
  BuildContext context, {
  required VoidCallback onPostProperty,
  required VoidCallback onPostReel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: AppShape.bottomSheetTop,
    ),
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ماذا تريد أن تنشر؟',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'اختر نوع المحتوى',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              _PublishOptionTile(
                icon: Icons.home_work_rounded,
                title: 'نشر عقار',
                subtitle: 'إعلان بيع أو إيجار مع صور وتفاصيل',
                accent: scheme.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  onPostProperty();
                },
              ),
              const SizedBox(height: 12),
              _PublishOptionTile(
                icon: Icons.play_circle_fill_rounded,
                title: 'نشر ريلز',
                subtitle: 'فيديو قصير يظهر في قسم الريلز',
                accent: AppColors.frameGold,
                onTap: () {
                  Navigator.pop(ctx);
                  onPostReel();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PublishOptionTile extends StatelessWidget {
  const _PublishOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 0,
      borderRadius: AppShape.borderLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShape.borderLg,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppShape.borderLg,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: AppShape.borderMd,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(icon, color: accent, size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
