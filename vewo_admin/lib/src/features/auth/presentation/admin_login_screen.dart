import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/api_config.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../routing/admin_routes.dart';
import '../auth_providers.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.postJson('auth/admin/login', {
        'phone': _phone.text.trim(),
        'password': _password.text,
      });
      await ref.read(adminSessionProvider).applyLoginResponse(data);
      if (!mounted) return;
      context.go(AdminRoutes.console);
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر الاتصال بالشبكة. تحقق من الإنترنت وحاول مجدداً.',
          ),
        ),
      );
    } on http.ClientException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إكمال الطلب. حاول مرة أخرى.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ. حاول مرة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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
                    AdminTheme.scaffoldDark,
                    AdminTheme.surfaceHighDark,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: scheme.primary.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Icon(Icons.admin_panel_settings_rounded,
                              size: 40, color: scheme.primary),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'vewo',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                            Text(
                              'لوحة المسؤول الرئيسي',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'تسجيل الدخول',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'يُقبل تسجيل الدخول لحساب المسؤول (admin) أو الموظف (staff).\n'
                                'بعد سكربت إعادة المستخدمين: هاتف 07871456361 وكلمة المرور ChangeMe!Admin2026',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                              ),
                              const SizedBox(height: 22),
                              TextFormField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'رقم الهاتف',
                                  hintText: '07XXXXXXXXX',
                                  prefixIcon: Icon(Icons.phone_android_rounded),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return 'مطلوب';
                                  if (!RegExp(r'^[0-9]+$').hasMatch(s)) {
                                    return 'أرقام فقط';
                                  }
                                  if (s.length != 11 || !s.startsWith('07')) {
                                    return 'رقم عراقي صالح: 11 رقماً يبدأ بـ 07';
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
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: 'إظهار / إخفاء',
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.length < 4) ? 'كلمة مرور غير صالحة' : null,
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _loading ? null : _submit,
                                icon: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.login_rounded),
                                label: Text(_loading ? 'جاري الدخول…' : 'دخول آمن'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'عنوان الـAPI الحالي: ${ApiConfig.baseUrl}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
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
