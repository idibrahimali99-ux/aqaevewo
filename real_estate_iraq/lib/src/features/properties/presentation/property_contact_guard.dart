import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_controller.dart';
import '../domain/property.dart';

/// يمنع فتح محادثة مع نفسك أو على منشور مُباع.
Future<bool> ensureCanOpenPropertyChat(
  BuildContext context,
  WidgetRef ref,
  Property property,
) async {
  if (property.isSold) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.sell_rounded, size: 48),
        title: const Text('تم البيع'),
        content: const Text(
          'هذا المنشور مُباع ولا يمكن فتح محادثة بخصوصه.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
    return false;
  }

  final me = ref.read(authControllerProvider).userId?.trim();
  final owner = property.ownerUserId?.trim();
  if (me != null && me.isNotEmpty && owner != null && owner.isNotEmpty && me == owner) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.person_off_rounded, size: 48),
        title: const Text('لا يمكن فتح المحادثة'),
        content: const Text(
          'أنت صاحب هذا المنشور — لا يمكنك مراسلة نفسك.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
    return false;
  }
  return true;
}
