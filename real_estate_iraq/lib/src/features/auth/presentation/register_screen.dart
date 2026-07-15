import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/vewo_api_client.dart';
import '../../../core/layout/app_responsive.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../core/widgets/map_location_picker_sheet.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../routing/app_routes.dart';
import '../data/auth_controller.dart';
import '../data/registration_marketer_provider.dart';
import '../domain/user_role.dart';

bool _isStrongPassword(String s) {
  if (s.length < 8) return false;
  if (!RegExp(r'[0-9]').hasMatch(s)) return false;
  // حروف لاتينية أو عربية (بدون أرقام فقط)
  if (!RegExp(r'[a-zA-Z\u0600-\u06FF]').hasMatch(s)) return false;
  return true;
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterRoleCards extends StatelessWidget {
  const _RegisterRoleCards({
    required this.selected,
    required this.isMarketer,
    required this.onPick,
  });

  final UserRole selected;
  final bool isMarketer;
  final void Function(UserRole role, {required bool marketer}) onPick;

  @override
  Widget build(BuildContext context) {
    final officeSelected = selected == UserRole.office && !isMarketer;
    final marketerSelected = selected == UserRole.office && isMarketer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _RegisterRoleCard(
                icon: Icons.person_outline_rounded,
                title: 'شخصي',
                selected: selected == UserRole.customer,
                onTap: () => onPick(UserRole.customer, marketer: false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RegisterRoleCard(
                icon: Icons.storefront_outlined,
                title: 'مكتب',
                selected: officeSelected,
                onTap: () => onPick(UserRole.office, marketer: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _RegisterRoleCard(
          icon: Icons.campaign_outlined,
          title: 'مسوّق عقاري',
          dense: true,
          selected: marketerSelected,
          onTap: () => onPick(UserRole.office, marketer: true),
        ),
      ],
    );
  }
}

class _RegisterRoleCard extends StatelessWidget {
  const _RegisterRoleCard({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final String title;
  final bool dense;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(dense ? 12 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: dense
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: dense
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _officeName = TextEditingController();
  final _iraqiPhone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _officeAddress = TextEditingController();
  final _officeLicense = TextEditingController();
  bool _loading = false;
  bool _uploadingPhoto = false;
  bool _obscure = true;
  String? _officePhotoPublicUrl;
  String? _profilePhotoPublicUrl;
  bool _isMarketer = false;
  LatLng? _officeMapLocation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final m = ref.read(registrationMarketerProvider);
      if (m && mounted) {
        setState(() => _isMarketer = true);
      }
    });
  }

  @override
  void dispose() {
    _fullName.dispose();
    _officeName.dispose();
    _iraqiPhone.dispose();
    _email.dispose();
    _password.dispose();
    _officeAddress.dispose();
    _officeLicense.dispose();
    super.dispose();
  }

  Future<void> _pickOfficePhoto(
    ImageSource source, {
    bool forProfile = false,
  }) async {
    setState(() => _uploadingPhoto = true);
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (x == null || !mounted) return;
      final Uint8List bytes = await x.readAsBytes();
      final api = VewoApiClient();
      try {
        final data = await api.postMultipartBytes(
          'register/office_photo',
          'file',
          bytes,
          'office.jpg',
        );
        final url = data['public_url']?.toString() ?? '';
        if (!mounted) return;
        if (url.length >= 12) {
          setState(() {
            if (forProfile) {
              _profilePhotoPublicUrl = url;
            } else {
              _officePhotoPublicUrl = url;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                forProfile ? 'تم رفع الصورة الشخصية' : 'تم رفع صورة المكتب',
              ),
            ),
          );
        }
      } on VewoApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      } finally {
        api.close();
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _showPhotoSourceSheet({bool forProfile = false}) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('معرض الصور'),
              onTap: () {
                Navigator.pop(ctx);
                _pickOfficePhoto(ImageSource.gallery, forProfile: forProfile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('الكاميرا'),
              onTap: () {
                Navigator.pop(ctx);
                _pickOfficePhoto(ImageSource.camera, forProfile: forProfile);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOfficeMapPicker() async {
    final res = await showMapLocationPicker(
      context,
      ref,
      initial: _officeMapLocation,
      title: 'موقع المكتب على الخريطة',
      showOptionalHint: true,
    );
    if (res != null && mounted) setState(() => _officeMapLocation = res);
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    final role = ref.read(authControllerProvider).role;
    if (role == UserRole.office) {
      if (_isMarketer) {
        final parts = _fullName.text.trim().split(RegExp(r'\s+'));
        if (parts.length < 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اكتب الاسم الثلاثي (3 كلمات)')),
          );
          return;
        }
        if ((_profilePhotoPublicUrl ?? '').length < 12) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الصورة الشخصية مطلوبة')),
          );
          return;
        }
      } else if (_officeName.text.trim().length < 2) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('اسم المكتب مطلوب')));
        return;
      }
      if (!_isMarketer && _officeAddress.text.trim().length < 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('عنوان المكتب مطلوب (5 أحرف على الأقل)'),
          ),
        );
        return;
      }
      if (!_isMarketer) {
        if (_officeLicense.text.trim().isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('رقم الإجازة مطلوب')));
          return;
        }
        if ((_officePhotoPublicUrl ?? '').length < 12) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ارفع صورة شعار المكتب من الزر أدناه'),
            ),
          );
          return;
        }
      }
    }
    setState(() => _loading = true);
    try {
      final err = await ref
          .read(authControllerProvider.notifier)
          .register(
            fullName: _fullName.text,
            iraqiPhone: _iraqiPhone.text,
            email: _email.text,
            password: _password.text,
            officeName: _isMarketer ? _fullName.text : _officeName.text,
            officeAddress: _officeAddress.text,
            officeLicenseNo: _officeLicense.text,
            officePhotoUrl: _officePhotoPublicUrl ?? '',
            profilePhotoUrl: _profilePhotoPublicUrl ?? '',
            isMarketer: _isMarketer,
            officeLat: _officeMapLocation?.latitude,
            officeLng: _officeMapLocation?.longitude,
          );
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
        return;
      }
      ref.read(registrationMarketerProvider.notifier).state = false;
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOffice = ref.watch(authControllerProvider).role == UserRole.office;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.18),
                    scheme.surface,
                    scheme.tertiaryContainer.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: AppResponsive.pagePadding(context, top: 8),
              child: ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(AppRoutes.login);
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    AppBrandMark(
                      variant: AppBrandMarkVariant.hero,
                      showTagline: false,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'إنشاء حساب',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    _RegisterRoleCards(
                      selected: ref.watch(authControllerProvider).role,
                      isMarketer: _isMarketer,
                      onPick: (role, {required marketer}) {
                        ref.read(registrationMarketerProvider.notifier).state =
                            marketer;
                        ref.read(authControllerProvider.notifier).setRole(role);
                        setState(() => _isMarketer = marketer);
                      },
                    ),
                    const SizedBox(height: 14),
                    Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(22),
                      color: scheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              if (isOffice && !_isMarketer) ...[
                                TextFormField(
                                  controller: _officeName,
                                  decoration: const InputDecoration(
                                    labelText: 'اسم المكتب',
                                    hintText: 'دار النخيل للعقارات',
                                    prefixIcon: Icon(Icons.apartment_rounded),
                                  ),
                                  validator: (v) {
                                    final s = (v ?? '').trim();
                                    if (s.length < 2) return 'اسم المكتب مطلوب';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                              ],
                              TextFormField(
                                controller: _fullName,
                                decoration: InputDecoration(
                                  labelText: _isMarketer
                                      ? 'الاسم الثلاثي'
                                      : (isOffice
                                            ? 'اسم ممثل المكتب'
                                            : 'الاسم الثلاثي'),
                                  hintText: _isMarketer || !isOffice
                                      ? 'علي حسن محمد'
                                      : 'أحمد علي',
                                  prefixIcon: const Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return 'الحقل مطلوب';
                                  if (_isMarketer || !isOffice) {
                                    final parts = s.split(RegExp(r'\s+'));
                                    if (parts.length < 3) {
                                      return 'اكتب الاسم الثلاثي (3 كلمات)';
                                    }
                                  } else if (s.length < 3) {
                                    return 'اسم الممثل قصير جداً';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _iraqiPhone,
                                keyboardType: TextInputType.phone,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  labelText: isOffice
                                      ? 'رقم الهاتف'
                                      : 'رقم الهاتف (رقم الزبون)',
                                  hintText: '07XXXXXXXXX',
                                  prefixIcon: const Icon(
                                    Icons.phone_iphone_rounded,
                                  ),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return 'الحقل مطلوب';
                                  if (!RegExp(r'^[0-9]+$').hasMatch(s)) {
                                    return 'رقم غير صالح';
                                  }
                                  if (s.length != 11) {
                                    return 'الرقم يجب أن يكون 11 رقم';
                                  }
                                  if (!s.startsWith('07')) {
                                    return 'يجب أن يبدأ بـ 07';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  labelText: 'البريد الإلكتروني (اختياري)',
                                  hintText: 'name@email.com',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                ),
                                validator: (v) {
                                  final s = (v ?? '').trim();
                                  if (s.isEmpty) return null;
                                  final ok = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  ).hasMatch(s);
                                  return ok ? null : 'البريد غير صالح';
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
                                validator: (v) {
                                  final s = v ?? '';
                                  if (!_isStrongPassword(s)) {
                                    return 'كلمة مرور ضعيفة — 8 أحرف مع حروف وأرقام';
                                  }
                                  return null;
                                },
                              ),
                              if (isOffice) ...[
                                const SizedBox(height: 10),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('مسوّق عقاري'),
                                  value: _isMarketer,
                                  onChanged: (v) {
                                    ref
                                            .read(
                                              registrationMarketerProvider
                                                  .notifier,
                                            )
                                            .state =
                                        v;
                                    setState(() => _isMarketer = v);
                                  },
                                ),
                              ],
                              if (isOffice && !_isMarketer) ...[
                                const SizedBox(height: 18),
                                Text(
                                  'بيانات المكتب (مطلوبة)',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _officeAddress,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'عنوان المكتب',
                                    prefixIcon: Icon(Icons.place_outlined),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _loading
                                      ? null
                                      : _openOfficeMapPicker,
                                  icon: const Icon(Icons.map_outlined),
                                  label: Text(
                                    _officeMapLocation == null
                                        ? 'تحديد الموقع على الخريطة (اختياري)'
                                        : 'تم تحديد الموقع — تعديل',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _officeLicense,
                                  decoration: const InputDecoration(
                                    labelText: 'رقم الإجازة',
                                    prefixIcon: Icon(Icons.badge_outlined),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'شعار المكتب (صورة)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _uploadingPhoto
                                      ? null
                                      : _showPhotoSourceSheet,
                                  icon: _uploadingPhoto
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.add_photo_alternate_outlined,
                                        ),
                                  label: Text(
                                    _officePhotoPublicUrl == null
                                        ? 'رفع صورة'
                                        : 'تغيير الصورة',
                                  ),
                                ),
                                if (_officePhotoPublicUrl != null) ...[
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      height: 120,
                                      width: double.infinity,
                                      child: CachedNetworkImage(
                                        imageUrl: _officePhotoPublicUrl!,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) => const Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                              if (isOffice && _isMarketer)
                                const SizedBox(height: 14),
                              const SizedBox(height: 16),
                              Text(
                                _isMarketer
                                    ? 'الصورة الشخصية (مطلوبة)'
                                    : 'الصورة الشخصية (اختياري)',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _uploadingPhoto
                                    ? null
                                    : () => _showPhotoSourceSheet(
                                        forProfile: true,
                                      ),
                                icon: const Icon(
                                  Icons.face_retouching_natural_outlined,
                                ),
                                label: Text(
                                  _profilePhotoPublicUrl == null
                                      ? 'رفع صورة شخصية'
                                      : 'تغيير الصورة الشخصية',
                                ),
                              ),
                              if (_profilePhotoPublicUrl != null) ...[
                                const SizedBox(height: 8),
                                CircleAvatar(
                                  radius: 40,
                                  backgroundImage: CachedNetworkImageProvider(
                                    _profilePhotoPublicUrl!,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              PrimaryButton(
                                label: 'إنشاء الحساب',
                                icon: Icons.person_add_alt_1_rounded,
                                isLoading: _loading,
                                onPressed: _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(AppRoutes.login);
                        }
                      },
                      child: const Text('لديك حساب؟ تسجيل الدخول'),
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
