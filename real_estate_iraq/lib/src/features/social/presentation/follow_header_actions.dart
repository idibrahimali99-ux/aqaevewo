import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/follow_providers.dart';

/// زر متابعة + عدد المتابعين (مكتب / مجمع / مقاطعة).
class FollowHeaderActions extends ConsumerWidget {
  const FollowHeaderActions({
    super.key,
    required this.targetKind,
    required this.targetId,
  });

  final String targetKind;
  final String targetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      followStatusProvider((kind: targetKind, id: targetId)),
    );
    return async.when(
      loading: () => const SizedBox(
        height: 36,
        width: 36,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (st) {
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline_rounded, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${st.followers} متابع',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            FilledButton.tonalIcon(
              onPressed: () async {
                try {
                  await ref.read(followListProvider.notifier).toggle(
                        targetKind: targetKind,
                        targetId: targetId,
                      );
                  ref.invalidate(
                    followStatusProvider((kind: targetKind, id: targetId)),
                  );
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تعذر تحديث المتابعة')),
                    );
                  }
                }
              },
              icon: Icon(
                st.following ? Icons.person_remove_rounded : Icons.person_add_rounded,
              ),
              label: Text(st.following ? 'إلغاء المتابعة' : 'متابعة'),
            ),
          ],
        );
      },
    );
  }
}
