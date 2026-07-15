import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/layout/app_responsive.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../routing/app_routes.dart';
import '../data/auth_controller.dart';
import '../data/registration_marketer_provider.dart';
import '../domain/user_role.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    setState(() => _loading = true);
    try {
      final err = await ref
          .read(authControllerProvider.notifier)
          .signIn(login: _login.text, password: _password.text);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
        return;
      }
      final role = ref.read(authControllerProvider).role;
      if (!mounted) return;
      if (role == UserRole.office) {
        context.go(AppRoutes.offices);
      } else {
        context.go(AppRoutes.home);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForgotPasswordWhatsApp() async {
    final text = Uri.encodeComponent(
      'مرحباً، نسيت كلمة المرور في تطبيق عقار تاون.',
    );
    final uri = Uri.parse('https://wa.me/9647871456361?text=$text');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب الآن')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    scheme.primary.withValues(alpha: 0.22),
                    scheme.surface,
                    scheme.primaryContainer.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: AppResponsive.pagePadding(context, top: 12),
              child: ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutBack,
                            builder: (context, v, child) => Transform.scale(
                              scale: 0.85 + 0.15 * v,
                              child: Opacity(opacity: v, child: child),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppBrandMark(
                                  variant: AppBrandMarkVariant.hero,
                                  showTagline: false,
                                  color: scheme.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.home),
                          child: const Text('تصفح كضيف'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _AccountTypeChooser(),
                    const SizedBox(height: 14),
                    Material(
                      elevation: 2,
                      shadowColor: scheme.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(22),
                      color: scheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _login,
                                keyboardType: TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  labelText: 'رقم الهاتف أو البريد الإلكتروني',
                                  hintText: '07XXXXXXXXX أو name@email.com',
                                  prefixIcon: Icon(
                                    Icons.alternate_email_rounded,
                                  ),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return 'الحقل مطلوب';
                                  if (s.contains('@')) {
                                    final ok = RegExp(
                                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                    ).hasMatch(s);
                                    return ok ? null : 'البريد غير صالح';
                                  }
                                  if (!RegExp(r'^07[0-9]{9}$').hasMatch(s)) {
                                    return 'رقم الهاتف يجب أن يبدأ بـ 07 ويتكون من 11 رقم';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _password,
                                obscureText: _obscure,
                                decoration: InputDecoration(
                                  labelText: 'كلمة المرور',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (v) => (v == null || v.length < 4)
                                    ? 'كلمة مرور غير صالحة'
                                    : null,
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton.icon(
                                  onPressed: _openForgotPasswordWhatsApp,
                                  icon: const Icon(Icons.lock_reset_rounded),
                                  label: const Text('هل نسيت كلمة السر؟'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              PrimaryButton(
                                label: 'دخول',
                                icon: Icons.login_rounded,
                                isLoading: _loading,
                                onPressed: _submit,
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    context.push(AppRoutes.register),
                                icon: const Icon(Icons.person_add_alt_rounded),
                                label: const Text('إنشاء حساب جديد'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTypeChooser extends ConsumerWidget {
  const _AccountTypeChooser();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).role;
    final isMarketer = ref.watch(registrationMarketerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _AccountTypeCard(
                icon: Icons.person_outline_rounded,
                title: 'شخصي',
                selected: role == UserRole.customer,
                onTap: () {
                  ref.read(registrationMarketerProvider.notifier).state = false;
                  ref
                      .read(authControllerProvider.notifier)
                      .setRole(UserRole.customer);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AccountTypeCard(
                icon: Icons.storefront_outlined,
                title: 'مكتب',
                selected: role == UserRole.office && !isMarketer,
                onTap: () {
                  ref.read(registrationMarketerProvider.notifier).state = false;
                  ref
                      .read(authControllerProvider.notifier)
                      .setRole(UserRole.office);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _AccountTypeCard(
          icon: Icons.campaign_outlined,
          title: 'مسوّق عقاري',
          selected: role == UserRole.office && isMarketer,
          onTap: () {
            ref.read(registrationMarketerProvider.notifier).state = true;
            ref.read(authControllerProvider.notifier).setRole(UserRole.office);
          },
        ),
      ],
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.75)
          : scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: scheme.primary, size: 28),
              const SizedBox(height: 7),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}
