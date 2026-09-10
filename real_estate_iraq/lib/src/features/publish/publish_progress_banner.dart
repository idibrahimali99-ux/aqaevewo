import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'publish_queue.dart';

class PublishProgressBanner extends ConsumerWidget {
  const PublishProgressBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(publishQueueProvider);
    if (!s.visible && (s.error == null || s.error!.isEmpty)) {
      return const SizedBox.shrink();
    }
    final err = s.error;
    final done = s.doneMessage;
    final color = err != null
        ? Theme.of(context).colorScheme.error
        : AppColors.frameGold;
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (s.busy)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      else
                        Icon(
                          err != null
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          color: color,
                          size: 22,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              err ??
                                  done ??
                                  (s.label.isEmpty ? 'جاري النشر…' : s.label),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (s.busy && s.detail.isNotEmpty)
                              Text(
                                s.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                          ],
                        ),
                      ),
                      if (!s.busy)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              ref.read(publishQueueProvider.notifier).dismiss(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                  if (s.busy) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: s.progress <= 0 ? null : s.progress,
                        color: AppColors.frameGold,
                        backgroundColor: AppColors.frameGold.withValues(
                          alpha: 0.18,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
