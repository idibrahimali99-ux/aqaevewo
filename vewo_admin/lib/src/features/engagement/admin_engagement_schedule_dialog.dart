import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_providers.dart';
import '../../core/api/vewo_api_client.dart';

/// حوار جدولة مشاهدات ولايكات بفترتين منفصلتين.
Future<void> showAdminEngagementScheduleDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String targetKind,
  required int publicNo,
  String? title,
  bool likesForProperty = true,
}) async {
  final viewsCtrl = TextEditingController(text: targetKind == 'reel' ? '5' : '1');
  final likesCtrl = TextEditingController(text: targetKind == 'reel' ? '2' : '0');
  final viewsIntervalCtrl = TextEditingController(text: '60');
  final likesIntervalCtrl = TextEditingController(text: '120');

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title ?? 'جدولة تفاعل #$publicNo'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'المشاهدات واللايكات لها فترات مستقلة — يمكن تشغيل أحدهما دون الآخر.',
                style: TextStyle(fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: viewsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'مشاهدات / فترة',
                            prefixIcon: Icon(Icons.visibility_outlined),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: viewsIntervalCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'فترة المشاهدات (ث)',
                            helperText: '60 = دقيقة',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: likesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'لايكات / فترة',
                            prefixIcon: const Icon(Icons.favorite_border_rounded),
                            helperText: likesForProperty
                                ? 'منشورات وريلز'
                                : 'ريلز فقط',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: likesIntervalCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'فترة اللايكات (ث)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('حفظ الجدولة'),
        ),
      ],
    ),
  );

  final v = int.tryParse(viewsCtrl.text.trim()) ?? 0;
  final l = int.tryParse(likesCtrl.text.trim()) ?? 0;
  final vSec = int.tryParse(viewsIntervalCtrl.text.trim()) ?? 60;
  final lSec = int.tryParse(likesIntervalCtrl.text.trim()) ?? 60;
  viewsCtrl.dispose();
  likesCtrl.dispose();
  viewsIntervalCtrl.dispose();
  likesIntervalCtrl.dispose();

  if (ok != true || (v < 1 && l < 1)) return;

  try {
    await ref.read(vewoApiClientProvider).postJson('admin/engagement', {
      'target_kind': targetKind,
      'target_public_no': publicNo,
      'views_per_tick': v,
      'likes_per_tick': l,
      'interval_seconds': vSec < 30 ? 30 : vSec,
      'views_interval_seconds': vSec < 30 ? 30 : vSec,
      'likes_interval_seconds': lSec < 30 ? 30 : lSec,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الجدولة')),
      );
    }
  } on VewoApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}
