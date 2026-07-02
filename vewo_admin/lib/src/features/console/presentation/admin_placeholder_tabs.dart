import 'package:flutter/material.dart';

class AdminPlaceholderTabs {
  AdminPlaceholderTabs._();

  static Widget officeApprovals(BuildContext context) {
    return _list(context, [
      const _PlaceholderCard(
        title: 'موافقة حساب مكتب',
        subtitle:
            'عرض طلبات التسجيل كمكتب، قبول يفعّل office_approved في قاعدة البيانات (يُربط بالـAPI).',
      ),
    ]);
  }

  static Widget postApprovals(BuildContext context) {
    return _list(context, [
      const _PlaceholderCard(
        title: 'موافقة منشورات الزبائن',
        subtitle: 'قبول/رفض العقارات ذات approval_status = pending قبل ظهورها في التطبيق.',
      ),
    ]);
  }

  static Widget mediationChats(BuildContext context) {
    return _list(context, [
      const _PlaceholderCard(
        title: 'محادثات وسيطة',
        subtitle: 'لوحة وسيط الأدمن بين الزبون والمكتب (تصميم جاهز للربط لاحقاً).',
      ),
    ]);
  }

  static Widget users(BuildContext context) {
    return _list(context, [
      const _PlaceholderCard(
        title: 'المستخدمون',
        subtitle: 'بحث، تفعيل/تعطيل، أدوار — واجهة احترافية بعد ربط جدول users.',
      ),
    ]);
  }

  static Widget settings(BuildContext context) {
    return _list(context, [
      const _PlaceholderCard(
        title: 'إعدادات اللوحة',
        subtitle: 'عنوان API، السجلات، النسخ الاحتياطي — قيد التطوير.',
      ),
    ]);
  }

  static Widget _list(BuildContext context, List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: children,
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.55,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
