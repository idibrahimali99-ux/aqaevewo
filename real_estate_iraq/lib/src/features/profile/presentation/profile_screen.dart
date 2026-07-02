import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/data/auth_state.dart';
import '../../auth/domain/user_role.dart';
import '../../properties/data/properties_providers.dart';
import '../../properties/domain/property.dart';
import '../../properties/presentation/property_mini_card.dart';

final myReelsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) async {
  final userId = ref.watch(authControllerProvider).userId?.trim();
  if (userId == null || userId.isEmpty) return const [];
  final data = await ref
      .read(vewoApiClientProvider)
      .getJson('reels/list', query: {'owner_id': userId, 'limit': '30'});
  final raw = data['items'];
  if (raw is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is Map<String, dynamic>) {
      out.add(item);
    } else if (item is Map) {
      out.add(Map<String, dynamic>.from(item));
    }
  }
  return out;
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(myPropertiesProvider);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Property> _filterMine(List<Property> mine, int tab) {
    return switch (tab) {
      0 =>
        mine.where((p) => !p.isSold && p.approvalStatus != 'rejected').toList(),
      1 => mine.where((p) => p.isSold).toList(),
      _ => mine.where((p) => p.approvalStatus == 'rejected').toList(),
    };
  }

  Future<void> _openAccountDetails(AuthState auth) async {
    final isOffice = auth.role == UserRole.office;
    final nameController = TextEditingController(
      text: isOffice ? auth.fullName : auth.displayName,
    );
    final officeNameController = TextEditingController(text: auth.officeName);
    var photoUrl = (isOffice ? auth.officePhotoUrl : auth.profilePhotoUrl)
        .trim();
    var uploading = false;
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickPhoto() async {
              setDialogState(() => uploading = true);
              try {
                final picked = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  maxWidth: 1200,
                );
                if (picked == null) return;
                final bytes = await picked.readAsBytes();
                final data = await ref
                    .read(vewoApiClientProvider)
                    .postMultipartBytes(
                      'register/office_photo',
                      'file',
                      bytes,
                      'profile.jpg',
                    );
                final uploaded = data['public_url']?.toString().trim() ?? '';
                if (uploaded.isNotEmpty) {
                  setDialogState(() => photoUrl = uploaded);
                }
              } finally {
                setDialogState(() => uploading = false);
              }
            }

            Future<void> save() async {
              final messenger = ScaffoldMessenger.of(this.context);
              final navigator = Navigator.of(dialogContext);
              setDialogState(() => saving = true);
              final err = await ref
                  .read(authControllerProvider.notifier)
                  .updateProfile(
                    fullName: nameController.text,
                    profilePhotoUrl: photoUrl,
                    officeName: isOffice ? officeNameController.text : null,
                  );
              if (!mounted) return;
              setDialogState(() => saving = false);
              if (err != null) {
                messenger.showSnackBar(SnackBar(content: Text(err)));
                return;
              }
              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('تم تحديث بيانات الحساب')),
              );
            }

            final currentAuth = ref.read(authControllerProvider);
            return AlertDialog(
              title: const Text('تفاصيل الحساب'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        alignment: AlignmentDirectional.bottomStart,
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl.isEmpty
                                ? Icon(
                                    currentAuth.role == UserRole.office
                                        ? Icons.business
                                        : Icons.person,
                                    size: 42,
                                  )
                                : null,
                          ),
                          FloatingActionButton.small(
                            heroTag: null,
                            onPressed: uploading ? null : pickPhoto,
                            child: uploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.camera_alt_outlined),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: isOffice
                          ? officeNameController
                          : nameController,
                      decoration: InputDecoration(
                        labelText: isOffice ? 'اسم المكتب' : 'الاسم',
                        prefixIcon: Icon(
                          isOffice
                              ? Icons.storefront_outlined
                              : Icons.badge_outlined,
                        ),
                      ),
                    ),
                    if (isOffice) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الثلاثي',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _ProfileInfoGrid(auth: currentAuth),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('إغلاق'),
                ),
                FilledButton.icon(
                  onPressed: saving || uploading ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    officeNameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final myProperties = ref.watch(myPropertiesProvider);
    final myReels = ref.watch(myReelsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const AppBarBrandTitle('الملف الشخصي'),
        actions: [
          IconButton(
            tooltip: themeMode == ThemeMode.dark
                ? 'الوضع الفاتح'
                : 'الوضع الداكن',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            icon: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myPropertiesProvider);
          ref.invalidate(myReelsProvider);
          await ref.read(propertyListingsProvider.notifier).reload();
          await ref
              .read(authControllerProvider.notifier)
              .refreshPostingFromServer();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openAccountDetails(auth),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: scheme.primaryContainer,
                            backgroundImage:
                                (auth.role == UserRole.office
                                        ? auth.officePhotoUrl
                                        : auth.profilePhotoUrl)
                                    .trim()
                                    .isNotEmpty
                                ? NetworkImage(
                                    (auth.role == UserRole.office
                                            ? auth.officePhotoUrl
                                            : auth.profilePhotoUrl)
                                        .trim(),
                                  )
                                : null,
                            child:
                                (auth.role == UserRole.office
                                        ? auth.officePhotoUrl
                                        : auth.profilePhotoUrl)
                                    .trim()
                                    .isEmpty
                                ? Icon(
                                    auth.role == UserRole.office
                                        ? Icons.business
                                        : Icons.person,
                                    color: scheme.primary,
                                    size: 32,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.role == UserRole.office &&
                                          auth.officeName.trim().isNotEmpty
                                      ? auth.officeName.trim()
                                      : auth.displayName,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                if (auth.role == UserRole.office &&
                                    auth.fullName.trim().isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    auth.fullName.trim(),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.black87),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'اضغط لعرض التفاصيل وتعديل الحساب',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_left_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Icon(Icons.assignment_outlined, color: scheme.primary),
                title: const Text(
                  'طلباتي العقارية',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('متابعة حالة طلبات اطلب عقارك'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => context.push(AppRoutes.myPropertyRequests),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'ريلزاتي',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.push('${AppRoutes.reels}?compose=1'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('نشر ريل'),
                ),
              ],
            ),
            myReels.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: Text('تعذر تحميل ريلزاتك')),
              ),
              data: (items) => items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: Text('لا توجد ريلز منشورة بعد')),
                    )
                  : SizedBox(
                      height: 156,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final reel = items[index];
                          return _MyReelCard(reel: reel);
                        },
                      ),
                    ),
            ),
            if (auth.role == UserRole.office ||
                auth.role == UserRole.customer) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    auth.role == UserRole.office ? 'إعلاناتي' : 'منشوراتي',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => context.push(AppRoutes.addProperty),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة'),
                  ),
                ],
              ),
              TabBar(
                controller: _tabs,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                tabs: const [
                  Tab(text: 'لم يُبَع'),
                  Tab(text: 'تم البيع'),
                  Tab(text: 'مرفوض'),
                ],
              ),
              const SizedBox(height: 8),
              myProperties.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('تعذر تحميل منشوراتك من قاعدة البيانات'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(myPropertiesProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
                data: (mine) => AnimatedBuilder(
                  animation: _tabs,
                  builder: (context, _) {
                    final items = _filterMine(mine, _tabs.index);
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('لا توجد منشورات في هذا القسم'),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final p in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: PropertyMiniCard(
                              property: p,
                              showModeration: true,
                              onTap: () => context.push(
                                '${AppRoutes.propertyDetails}/${p.id}',
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoGrid extends StatelessWidget {
  const _ProfileInfoGrid({required this.auth});

  final AuthState auth;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, String value})>[
      (
        icon: Icons.badge_outlined,
        label: 'الاسم',
        value: auth.displayName.toString(),
      ),
      (
        icon: Icons.phone_iphone_rounded,
        label: 'رقم الهاتف',
        value: auth.phone.toString().trim().isEmpty ? 'غير محدد' : auth.phone,
      ),
      if (auth.email.trim().isNotEmpty)
        (icon: Icons.email_outlined, label: 'البريد', value: auth.email),
      (
        icon: Icons.account_circle_outlined,
        label: 'نوع الحساب',
        value: auth.role == UserRole.office ? 'مكتب / مسوّق' : 'زبون',
      ),
      if (auth.role == UserRole.office)
        (
          icon: Icons.inventory_2_outlined,
          label: 'رصيد النشر',
          value: auth.postingTrialUnlimited == true
              ? 'بلا حدود'
              : auth.postingListingsRemaining != null
              ? '${auth.postingListingsRemaining} منشور'
              : 'غير محدد',
        ),
    ];

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ProfileInfoTile(
              icon: item.icon,
              label: item.label,
              value: item.value,
            ),
          ),
      ],
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection:
                        label.contains('رقم') || label.contains('معرّف')
                        ? TextDirection.ltr
                        : null,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyReelCard extends StatelessWidget {
  const _MyReelCard({required this.reel});

  final Map<String, dynamic> reel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final id = reel['id']?.toString() ?? '';
    final caption = reel['caption']?.toString().trim() ?? '';
    final videoUrl = reel['video_public_url']?.toString().trim() ?? '';
    final views = reel['view_count'] ?? reel['views_count'] ?? 0;
    final likes = reel['likes_count'] ?? 0;

    return SizedBox(
      width: 132,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: id.isEmpty
              ? null
              : () => context.push('${AppRoutes.reels}?reel_id=$id'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Icon(
                        videoUrl.isEmpty
                            ? Icons.video_collection_outlined
                            : Icons.play_circle_fill_rounded,
                        color: Colors.white70,
                        size: 42,
                      ),
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.48),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption.isEmpty ? 'ريل بدون وصف' : caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$views مشاهدة · $likes إعجاب',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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
