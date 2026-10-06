import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_responsive.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../routing/app_routes.dart';
import '../data/auth_controller.dart';
import '../data/registration_marketer_provider.dart';
import '../domain/user_role.dart';

class RoleSelectScreen extends ConsumerWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final selected = auth.role;

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const AppBarBrandTitle('اختيار نوع المستخدم')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppResponsive.pagePadding(context),
          child: ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RoleCard(
                  title: UserRole.customer.labelAr,
                  subtitle:
                      'تصفّح، تواصل مع المسؤول عند الحاجة، المفضّلة — بدون وسيط مع المكتب',
                  icon: Icons.person_outline,
                  isSelected: selected == UserRole.customer,
                  onTap: () {
                    ref.read(registrationMarketerProvider.notifier).state =
                        false;
                    ref
                        .read(authControllerProvider.notifier)
                        .setRole(UserRole.customer);
                  },
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  title: UserRole.office.labelAr,
                  subtitle:
                      'نشر مباشر بعد التفعيل، عنوان وإجازة وصورة للمكتب عند التسجيل',
                  icon: Icons.business_outlined,
                  isSelected:
                      selected == UserRole.office &&
                      !ref.watch(registrationMarketerProvider),
                  onTap: () {
                    ref.read(registrationMarketerProvider.notifier).state =
                        false;
                    ref
                        .read(authControllerProvider.notifier)
                        .setRole(UserRole.office);
                  },
                ),
                const SizedBox(height: 12),
                _RoleCard(
                  title: 'مسوّق عقاري',
                  subtitle:
                      'نفس صلاحيات المكتب — تسجيل مبسّط دون إجازة وشعار إلزاميين',
                  icon: Icons.campaign_outlined,
                  isSelected:
                      selected == UserRole.office &&
                      ref.watch(registrationMarketerProvider),
                  onTap: () {
                    ref.read(registrationMarketerProvider.notifier).state =
                        true;
                    ref
                        .read(authControllerProvider.notifier)
                        .setRole(UserRole.office);
                  },
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'متابعة',
                  icon: Icons.check,
                  onPressed: () => context.push(AppRoutes.login),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primary.withValues(alpha: 0.10),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: cs.primary)
            else
              Icon(Icons.circle_outlined, color: cs.outline),
          ],
        ),
      ),
    );
  }
}
