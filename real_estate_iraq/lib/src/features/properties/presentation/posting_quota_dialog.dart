import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// نافذة منبثقة عند انتهاء رصيد النشر للمكتب/المسوّق.
Future<void> showPostingQuotaBlockedDialog(BuildContext context) async {
  const phone = '07871456361';
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('لا يمكن النشر'),
      content: const Text(
        'انتهت منشوراتك المتاحة. للمكاتب والمسوّقين العقاريين: يرجى الاشتراك '
        'للتواصل مع الإدارة عبر واتساب $phone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إغلاق'),
        ),
        TextButton.icon(
          icon: Icon(
            Icons.chat_rounded,
            color: Theme.of(ctx).extension<VewoExtras>()?.whatsApp ??
                AppColors.whatsAppLight,
          ),
          label: const Text('واتساب'),
          onPressed: () async {
            final uri = Uri.parse('https://wa.me/9647871456361');
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
        FilledButton.icon(
          icon: const Icon(Icons.call_rounded),
          label: const Text(phone),
          onPressed: () async {
            final uri = Uri.parse('tel:$phone');
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
      ],
    ),
  );
}

bool officePostingQuotaExhausted({
  required bool isOffice,
  required bool? postingTrialUnlimited,
  required int? postingListingsRemaining,
}) {
  if (!isOffice) return false;
  if (postingTrialUnlimited == null) return false;
  if (postingTrialUnlimited == true) return false;
  return (postingListingsRemaining ?? 0) <= 0;
}
