import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/app_bootstrap_provider.dart';
import '../../../core/layout/app_responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../core/widgets/notification_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../../routing/app_routes.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../../../core/api/api_providers.dart';
import '../../properties/data/properties_providers.dart';
import '../../properties/domain/property.dart';
import '../../properties/domain/property_category.dart';
import '../../properties/presentation/property_card.dart';
import '../../news/domain/property_news_models.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../offices/data/offices_providers.dart';

final homeRefreshSignalProvider = StateProvider<int>((ref) => 0);

double _cw(num value) => value.w.clamp(0.0, value.toDouble()).toDouble();
double _ch(num value) => value.h.clamp(0.0, value.toDouble()).toDouble();
double _cr(num value) => value.r.clamp(0.0, value.toDouble()).toDouble();
double _csp(num value) => value.sp.clamp(0.0, value.toDouble()).toDouble();

/// إعلانات ذات `slot` للصفحة الرئيسية فقط (أو بدون تحديد = الرئيسية).
bool _promoVisibleOnHome(HomePromotion p) {
  final s = p.slot.trim().toLowerCase();
  return s.isEmpty || s == 'home' || s == 'main';
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).refreshPostingFromServer();
      ref.invalidate(parcelsListProvider);
      ref.invalidate(compoundsListProvider);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshHome() async {
    await ref.read(propertyListingsProvider.notifier).reload();
    final _ = await ref.refresh(appBootstrapProvider.future);
    ref.invalidate(parcelsListProvider);
    ref.invalidate(compoundsListProvider);
    await ref.read(authControllerProvider.notifier).refreshPostingFromServer();
  }

  Future<void> _scrollTopAndRefresh() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
    await _refreshHome();
  }

  void _openSearch(BuildContext context, String query) {
    final q = query.trim();
    if (q.isEmpty) {
      context.push(AppRoutes.search);
    } else {
      context.push('${AppRoutes.search}?q=${Uri.encodeComponent(q)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeRefreshSignalProvider, (previous, next) {
      if (previous == null || previous == next) return;
      _scrollTopAndRefresh();
    });
    final mostViewed = ref.watch(mostViewedProvider);
    final allProperties = ref.watch(allPropertiesProvider);
    final propertiesLoading = ref.watch(propertyListingsLoadingProvider);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshHome,
        displacement: 18,
        edgeOffset: 12,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              centerTitle: true,
              backgroundColor: AppColors.headerTop,
              flexibleSpace: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.headerTop, AppColors.headerBottom],
                  ),
                ),
              ),
              surfaceTintColor: Colors.transparent,
              foregroundColor: AppColors.onBrand,
              iconTheme: const IconThemeData(color: AppColors.onBrand),
              actionsIconTheme: const IconThemeData(color: AppColors.onBrand),
              title: const AppBrandMark(
                variant: AppBrandMarkVariant.compact,
                color: AppColors.textPrimary,
              ),
              leading: const SizedBox.shrink(),
              actions: [
                IconButton(
                  tooltip: 'الإشعارات',
                  onPressed: () async {
                    if (!auth.isAuthenticated) {
                      context.push(AppRoutes.login);
                      return;
                    }
                    await context.push(AppRoutes.notifications);
                    ref.invalidate(appNotifCountsProvider);
                  },
                  icon: ref.watch(appNotifCountsProvider).when(
                    loading: () => const Icon(Icons.notifications_none_rounded),
                    error: (_, _) =>
                        const Icon(Icons.notifications_none_rounded),
                    data: (m) => NotificationIconWithBadge(
                      count: sumAppNotifCounts(m),
                      style: NotificationBadgeStyle.onBrandHeader,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'المحفوظات',
                  onPressed: auth.isAuthenticated
                      ? () => context.push(AppRoutes.favorites)
                      : () => context.push(AppRoutes.login),
                  icon: const Icon(Icons.bookmarks_outlined),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(_cw(14), _ch(12), _cw(14), 0),
                child: const _HomePromotionsBlock(),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: _ch(7))),
            const SliverToBoxAdapter(child: _QuickNavRow()),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(_cw(14), _ch(3), _cw(14), _ch(10)),
              sliver: SliverToBoxAdapter(
                child: _HomeSearchPanel(
                  onSearch: (q) => _openSearch(context, q),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _UrgentSaleSection(items: allProperties)),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(_cw(14), 0, _cw(14), _ch(7)),
                child: const _OfficePostingQuotaStrip(),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: _ch(7))),
            if (propertiesLoading && mostViewed.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: _cw(14)),
                  child: const SectionHeader(title: 'الأكثر مشاهدة'),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: _ch(5))),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: _cw(14)),
                      child: _PropertySlider(items: mostViewed),
                    ),
                    if (mostViewed.length == 5)
                      _ShowMoreButton(
                        label: 'عرض المزيد',
                        onPressed: () => context.push(AppRoutes.search),
                      ),
                  ],
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Consumer(
                builder: (context, ref, _) {
                  final near = ref.watch(nearestToMeProvider);
                  if (near.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: _ch(8)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: _cw(14)),
                        child: const SectionHeader(title: 'الأقرب إليك'),
                      ),
                      SizedBox(height: _ch(8)),
                      _PropertySlider(items: near),
                      SizedBox(height: _ch(8)),
                    ],
                  );
                },
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: _ch(5))),
            const SliverToBoxAdapter(child: _ParcelsHub()),
            SliverToBoxAdapter(child: SizedBox(height: _ch(10))),
            const SliverToBoxAdapter(child: _CompoundsHub()),
            SliverToBoxAdapter(child: SizedBox(height: _ch(10))),
            SliverToBoxAdapter(
              child: _CategorySection(
                title: 'أراضي',
                category: PropertyCategory.land,
                moreQuery: 'cat=land',
              ),
            ),
            SliverToBoxAdapter(
              child: _CategorySection(
                title: 'بيوت',
                category: PropertyCategory.house,
                moreQuery: 'cat=house',
              ),
            ),
            SliverToBoxAdapter(
              child: _CategorySection(
                title: 'شقق',
                category: PropertyCategory.apartment,
                moreQuery: 'cat=apartment',
              ),
            ),
            SliverToBoxAdapter(
              child: _CategorySection(
                title: 'محلات',
                category: PropertyCategory.shop,
                moreQuery: 'cat=shop',
              ),
            ),
            SliverToBoxAdapter(
              child: _CategorySection(
                title: 'فلل',
                category: PropertyCategory.villa,
                moreQuery: 'cat=villa',
              ),
            ),
            SliverToBoxAdapter(
              child: _CategorySection(
                title: 'مجمعات',
                category: PropertyCategory.compound,
                moreQuery: 'cat=compound',
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(_cw(14), _ch(8), _cw(14), 0),
                child: const _HomePropertyNewsBlock(),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: AppResponsive.shellContentBottomPadding(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// قسم المقاطعات في الرئيسية (بدون تقسيم أراضي/مجمعات).
class _ParcelsHub extends ConsumerWidget {
  const _ParcelsHub();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parcelsAsync = ref.watch(parcelsListProvider);

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.grid_view_rounded,
                      color: scheme.primary,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'المقاطعات',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.parcels),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          parcelsAsync.when(
            loading: () => const SizedBox(
              height: 88,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (parcels) {
              if (parcels.isEmpty) return const SizedBox.shrink();
              final top = [...parcels];
              top.sort((a, b) => b.postsCount.compareTo(a.postsCount));
              final items = top.take(10).toList();
              return SizedBox(
                height: 98,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final p = items[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        final title = Uri.encodeComponent(p.displayName);
                        context.push(
                          '${AppRoutes.parcelProfile}/${p.id}?title=$title',
                        );
                      },
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    p.governorate,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: scheme.primary.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '${p.postsCount}',
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// مجمّعات سكنية — نفس أسلوب المقاطعات (منشورات يضيفها الأدمن).
class _CompoundsHub extends ConsumerWidget {
  const _CompoundsHub();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compoundsAsync = ref.watch(compoundsListProvider);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.location_city_rounded,
                      color: scheme.primary,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'المجمعات السكنية',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.compounds),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          compoundsAsync.when(
            loading: () => const SizedBox(
              height: 88,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (compounds) {
              if (compounds.isEmpty) return const SizedBox.shrink();
              final top = [...compounds];
              top.sort((a, b) => b.postsCount.compareTo(a.postsCount));
              final items = top.take(10).toList();
              return SizedBox(
                height: 98,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final c = items[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        final title = Uri.encodeComponent(c.displayName);
                        context.push(
                          '${AppRoutes.compoundProfile}/${c.id}?title=$title',
                        );
                      },
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Icon(
                                  Icons.apartment_rounded,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    c.governorate,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: scheme.primary.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '${c.postsCount}',
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends ConsumerWidget {
  const _CategorySection({
    required this.title,
    required this.category,
    required this.moreQuery,
  });

  final String title;
  final PropertyCategory category;
  final String moreQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Property> items = ref.watch(
      topFiveStandardByCategoryProvider(category),
    );

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(title: title),
        ),
        const SizedBox(height: 6),
        _PropertySlider(items: items),
        if (items.length == 5)
          _ShowMoreButton(
            label: 'عرض المزيد',
            onPressed: () => context.push('${AppRoutes.search}?$moreQuery'),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
          label: Text(label),
        ),
      ),
    );
  }
}

class _UrgentSaleSection extends StatelessWidget {
  const _UrgentSaleSection({required this.items});

  final List<Property> items;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final urgent = items.where((p) {
      if (p.isSold || p.detailsJson?['urgent_sale'] != true) return false;
      final endsAt = _urgentSaleEndsAt(p);
      return endsAt == null || endsAt.isAfter(now);
    }).toList();
    if (urgent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _cw(14)),
          child: Row(
            children: [
              Text('🔥', style: TextStyle(fontSize: _csp(24))),
              SizedBox(width: _cw(7)),
              Text(
                'البيع العاجل',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: _csp(21),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _ch(7)),
        SizedBox(
          height: _ch(356),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: _cw(14)),
            itemCount: urgent.length,
            separatorBuilder: (_, _) => SizedBox(width: _cw(9)),
            itemBuilder: (context, index) =>
                _UrgentSaleCard(property: urgent[index]),
          ),
        ),
        SizedBox(height: _ch(12)),
      ],
    );
  }
}

class _UrgentSaleCard extends StatelessWidget {
  const _UrgentSaleCard({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _cw(214),
      child: PropertyCard(
        property: property,
        onTap: () =>
            context.push('${AppRoutes.propertyDetails}/${property.id}'),
      ),
    );
  }
}

DateTime? _urgentSaleEndsAt(Property p) {
  final raw = p.detailsJson?['urgent_sale_expires_at']?.toString();
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

/// شريط رصيد المنشورات للمكاتب (بعد تفعيل أعمدة الباقة في الخادم).
class _OfficePostingQuotaStrip extends ConsumerWidget {
  const _OfficePostingQuotaStrip();

  static const _supportPhone = '07871456361';

  Future<void> _openWa(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/9647871456361');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
    }
  }

  Future<void> _openTel(BuildContext context) async {
    final uri = Uri.parse('tel:$_supportPhone');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('اتصل يدوياً: $_supportPhone')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isAuthenticated ||
        auth.role != UserRole.office ||
        !auth.officeApproved) {
      return const SizedBox.shrink();
    }
    final trial = auth.postingTrialUnlimited;
    final rem = auth.postingListingsRemaining;
    if (trial == null) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;

    if (trial) {
      return Material(
        borderRadius: BorderRadius.circular(16),
        color: scheme.secondaryContainer.withValues(alpha: 0.65),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.all_inclusive_rounded,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'الباقة التجريبية: نشر غير محدود حالياً',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final left = rem ?? 0;
    final exhausted = left <= 0;

    return Material(
      borderRadius: BorderRadius.circular(16),
      color: exhausted
          ? scheme.errorContainer.withValues(alpha: 0.75)
          : scheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  exhausted
                      ? Icons.warning_amber_rounded
                      : Icons.post_add_outlined,
                  color: exhausted
                      ? scheme.onErrorContainer
                      : scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    exhausted
                        ? 'نفدت حصة منشورات باقتك. يمكنك التصفح والمحادثات فقط. تواصل مع الدعم لزيادة الرصيد.'
                        : 'منشورات متبقية في باقتك: $left',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: exhausted
                          ? scheme.onErrorContainer
                          : scheme.onPrimaryContainer,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            if (exhausted) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openWa(context),
                      icon: Icon(
                        Icons.chat_rounded,
                        color:
                            Theme.of(
                              context,
                            ).extension<VewoExtras>()?.whatsApp ??
                            AppColors.whatsAppLight,
                      ),
                      label: const Text('واتساب الدعم'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _openTel(context),
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('اتصال'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// شريط البحث أول الصفحة.
class _HomeSearchPanel extends ConsumerStatefulWidget {
  const _HomeSearchPanel({required this.onSearch});

  final void Function(String query) onSearch;

  @override
  ConsumerState<_HomeSearchPanel> createState() => _HomeSearchPanelState();
}

class _HomeSearchPanelState extends ConsumerState<_HomeSearchPanel> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _submit() => widget.onSearch(_query.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Material(
            elevation: 10,
            shadowColor: AppColors.brandPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(_cr(24)),
            color: scheme.surface,
            child: Container(
              height: _ch(52),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_cr(24)),
                color: Colors.white,
                border: Border.all(color: AppColors.borderLight),
              ),
              padding: EdgeInsetsDirectional.fromSTEB(
                _cw(8),
                _ch(4),
                _cw(4),
                _ch(4),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'فلترة',
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.headerBottom,
                    ),
                    onPressed: () =>
                        context.push('${AppRoutes.search}?filter=1'),
                    icon: Icon(Icons.tune_rounded, size: _cr(24)),
                  ),
                  SizedBox(width: _cw(4)),
                  Expanded(
                    child: TextField(
                      controller: _query,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {},
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن موقع أو اسم العقار',
                        hintStyle: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.72,
                              ),
                              fontWeight: FontWeight.w800,
                              fontSize: _csp(13),
                            ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: _cw(8),
                          vertical: _ch(9),
                        ),
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: _csp(13),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: _cw(8)),
        Material(
          elevation: 8,
          shadowColor: AppColors.frameGold.withValues(alpha: 0.18),
          color: AppColors.mapPin,
          borderRadius: BorderRadius.circular(_cr(18)),
          child: InkWell(
            onTap: _submit,
            borderRadius: BorderRadius.circular(_cr(18)),
            child: SizedBox(
              width: _cw(52),
              height: _ch(52),
              child: Icon(
                Icons.search_rounded,
                color: AppColors.onBrand,
                size: _cr(24),
              ),
            ),
          ),
        ),
        SizedBox(width: _cw(8)),
        Material(
          elevation: 8,
          shadowColor: AppColors.frameGold.withValues(alpha: 0.18),
          color: AppColors.frameGold,
          borderRadius: BorderRadius.circular(_cr(18)),
          child: InkWell(
            onTap: () => context.push(AppRoutes.propertiesMap),
            borderRadius: BorderRadius.circular(_cr(18)),
            child: SizedBox(
              width: _cw(52),
              height: _ch(52),
              child: Icon(
                Icons.location_on,
                color: AppColors.onBrand,
                size: _cr(25),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// إعلانات (سلايدر) بعد البحث والأقسام.
class _HomePromotionsBlock extends ConsumerWidget {
  const _HomePromotionsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appBootstrapProvider);
    return async.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'جاري التحميل…',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [SizedBox(height: 18)],
      ),
      data: (data) {
        final sliderPromos = data.promotions
            .where((p) => p.showsInSlider && _promoVisibleOnHome(p))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sliderPromos.isNotEmpty)
              _AdsAutoCarousel(promotions: sliderPromos)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  borderRadius: BorderRadius.circular(18),
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'لا توجد إعلانات في السلايدر حالياً.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
          ],
        );
      },
    );
  }
}

/// أخبار العقارات — تحت خانة البحث.
class _HomePropertyNewsBlock extends ConsumerWidget {
  const _HomePropertyNewsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appBootstrapProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data.propertyNews.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(title: 'أخبار العقارات'),
            const SizedBox(height: 10),
            _PropertyNewsStrip(items: data.propertyNews),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _QuickNavRow extends ConsumerWidget {
  const _QuickNavRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appBootstrapProvider);
    final serverItems = async.maybeWhen(
      data: (data) => data.homeSections,
      orElse: () => const <HomeSectionConfig>[],
    );
    final items = _homeSectionsWithRequiredItems(serverItems);
    return SizedBox(
      height: _ch(82),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: _cw(12), vertical: _ch(3)),
        children: [
          _RequestPropertyChip(
            onTap: () => context.push(AppRoutes.requestProperty),
          ),
          for (final item in items)
            _QuickNavChip(
              label: item.label,
              icon: _homeSectionIcon(item.iconName),
              assetPath: item.key == 'parcels' ? '../icon/1.png' : null,
              onTap: () => _openHomeSection(context, item.routeTarget),
            ),
        ],
      ),
    );
  }
}

List<HomeSectionConfig> _homeSectionsWithRequiredItems(
  List<HomeSectionConfig> serverItems,
) {
  if (serverItems.isEmpty) return _defaultHomeSections;
  final hasMarketers = serverItems.any((item) => item.key == 'marketers');
  if (hasMarketers) return serverItems;
  final merged = <HomeSectionConfig>[...serverItems, _marketersHomeSection]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return merged;
}

const _marketersHomeSection = HomeSectionConfig(
  key: 'marketers',
  label: 'المسوقين',
  iconName: 'person',
  routeTarget: AppRoutes.marketers,
  sortOrder: 15,
  isActive: true,
);

const _defaultHomeSections = <HomeSectionConfig>[
  HomeSectionConfig(
    key: 'offices',
    label: 'المكاتب',
    iconName: 'apartment',
    routeTarget: AppRoutes.offices,
    sortOrder: 10,
    isActive: true,
  ),
  _marketersHomeSection,
  HomeSectionConfig(
    key: 'parcels',
    label: 'المقاطعات',
    iconName: 'grid',
    routeTarget: AppRoutes.parcels,
    sortOrder: 20,
    isActive: true,
  ),
  HomeSectionConfig(
    key: 'compounds',
    label: 'مجمعات سكنية',
    iconName: 'city',
    routeTarget: AppRoutes.compounds,
    sortOrder: 30,
    isActive: true,
  ),
  HomeSectionConfig(
    key: 'house',
    label: 'بيوت',
    iconName: 'home',
    routeTarget: '${AppRoutes.search}?cat=house',
    sortOrder: 40,
    isActive: true,
  ),
  HomeSectionConfig(
    key: 'land',
    label: 'أراضي',
    iconName: 'land',
    routeTarget: '${AppRoutes.search}?cat=land',
    sortOrder: 50,
    isActive: true,
  ),
  HomeSectionConfig(
    key: 'apartment',
    label: 'شقق',
    iconName: 'building',
    routeTarget: '${AppRoutes.search}?cat=apartment',
    sortOrder: 60,
    isActive: true,
  ),
  HomeSectionConfig(
    key: 'shop',
    label: 'محلات',
    iconName: 'shop',
    routeTarget: '${AppRoutes.search}?cat=shop',
    sortOrder: 70,
    isActive: true,
  ),
  HomeSectionConfig(
    key: 'villa',
    label: 'فلل',
    iconName: 'villa',
    routeTarget: '${AppRoutes.search}?cat=villa',
    sortOrder: 80,
    isActive: true,
  ),
];

IconData _homeSectionIcon(String iconName) {
  switch (iconName.trim()) {
    case 'apartment':
      return Icons.apartment_rounded;
    case 'building':
      return Icons.domain_rounded;
    case 'city':
      return Icons.location_city_outlined;
    case 'grid':
      return Icons.grid_view_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'key':
      return Icons.vpn_key_rounded;
    case 'land':
      return Icons.park_outlined;
    case 'person':
      return Icons.person_pin_circle_rounded;
    case 'sale':
      return Icons.sell_rounded;
    case 'shop':
      return Icons.storefront_outlined;
    case 'villa':
      return Icons.villa_outlined;
    default:
      return Icons.widgets_rounded;
  }
}

void _openHomeSection(BuildContext context, String routeTarget) {
  final target = routeTarget.trim();
  if (target.isEmpty) return;
  context.push(target.startsWith('/') ? target : '/$target');
}

class _RequestPropertyChip extends StatelessWidget {
  const _RequestPropertyChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(end: _cw(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_cr(18)),
        child: SizedBox(
          width: _cw(92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _cw(92),
                height: _ch(58),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFAE7A5),
                      AppColors.frameGold,
                      AppColors.brandPrimary,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(_cr(18)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.88),
                    width: _cw(1.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.frameGold.withValues(alpha: 0.34),
                      blurRadius: _cr(16),
                      offset: Offset(0, _ch(7)),
                    ),
                    BoxShadow(
                      color: AppColors.brandPrimary.withValues(alpha: 0.12),
                      blurRadius: _cr(10),
                      offset: Offset(0, _ch(3)),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    PositionedDirectional(
                      top: _ch(6),
                      end: _cw(7),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: _cw(5),
                          vertical: _ch(1.5),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(_cr(999)),
                        ),
                        child: Text(
                          'طلب',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _csp(8),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        Icons.real_estate_agent_rounded,
                        color: Colors.white,
                        size: _cr(27),
                      ),
                    ),
                    PositionedDirectional(
                      start: _cw(9),
                      bottom: _ch(6),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: _cr(15),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: _ch(4)),
              Text(
                'اطلب عقارك',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.brandPrimary,
                  fontSize: _csp(10.6),
                ),
              ),
              Text(
                'نبحث لك',
                maxLines: 1,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.frameGold,
                  fontSize: _csp(8),
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickNavChip extends StatelessWidget {
  const _QuickNavChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.assetPath,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    const gold = AppColors.frameGold;
    return Padding(
      padding: EdgeInsetsDirectional.only(end: _cw(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_cr(15)),
        child: SizedBox(
          width: _cw(62),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _cw(62),
                height: _ch(58),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_cr(15)),
                  border: Border.all(
                    color: gold.withValues(alpha: 0.28),
                    width: _cw(1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.055),
                      blurRadius: _cr(8),
                      offset: Offset(0, _ch(3)),
                    ),
                    BoxShadow(
                      color: gold.withValues(alpha: 0.08),
                      blurRadius: _cr(14),
                      offset: Offset(0, _ch(6)),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: _cw(32),
                    height: _cw(32),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(_cr(13)),
                    ),
                    child: assetPath == null
                        ? Icon(icon, size: _cr(22), color: gold)
                        : Padding(
                            padding: EdgeInsets.all(_cw(8)),
                            child: ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                gold,
                                BlendMode.srcIn,
                              ),
                              child: Image.asset(
                                assetPath!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    Icon(icon, size: _cr(21), color: gold),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              SizedBox(height: _ch(4)),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.brandPrimary,
                  fontSize: _csp(10.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _onPromotionTap(BuildContext context, HomePromotion p) async {
  final t = p.linkTarget.trim();
  if (t.isEmpty) return;
  final linkType = p.linkType.trim().toLowerCase();
  if (linkType == 'property') {
    context.push('${AppRoutes.propertyDetails}/$t');
    return;
  }
  if (linkType == 'property_no') {
    final no = t.replaceFirst(RegExp(r'^#+'), '');
    if (no.isEmpty) return;
    try {
      final api = ProviderScope.containerOf(
        context,
      ).read(vewoApiClientProvider);
      final data = await api.getJson(
        'properties/list',
        query: {'public_no': no, 'limit': '1'},
      );
      final raw = data['items'];
      if (raw is List && raw.isNotEmpty) {
        final first = raw.first;
        final map = first is Map<String, dynamic>
            ? first
            : (first is Map ? Map<String, dynamic>.from(first) : null);
        final id = map?['id']?.toString() ?? '';
        if (id.isNotEmpty && context.mounted) {
          context.push('${AppRoutes.propertyDetails}/$id');
          return;
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('لم يتم العثور على المنشور #$no')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الإعلان حالياً')),
        );
      }
    }
    return;
  }
  if (t.startsWith('/')) {
    context.push(t);
    return;
  }
  if (linkType == 'route') {
    context.push(t.startsWith('/') ? t : '/$t');
    return;
  }
  final uri = Uri.tryParse(t);
  if (uri != null &&
      uri.hasScheme &&
      (uri.scheme == 'http' || uri.scheme == 'https')) {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return;
  }
  if (uri != null &&
      uri.hasScheme &&
      (uri.scheme == 'tel' || uri.scheme == 'mailto')) {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// سلايدر إعلانات يتقدّم تلقائياً مع مؤشرات.
class _AdsAutoCarousel extends StatefulWidget {
  const _AdsAutoCarousel({required this.promotions});

  final List<HomePromotion> promotions;

  @override
  State<_AdsAutoCarousel> createState() => _AdsAutoCarouselState();
}

class _AdsAutoCarouselState extends State<_AdsAutoCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    if (widget.promotions.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        final next = (_index + 1) % widget.promotions.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 640),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = widget.promotions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _ch(176),
          child: PageView.builder(
            controller: _pageController,
            itemCount: n,
            padEnds: true,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final p = widget.promotions[i];
              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _cw(4),
                  vertical: _ch(4),
                ),
                child: Material(
                  elevation: 8,
                  shadowColor: scheme.primary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(_cr(20)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _onPromotionTap(context, p),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: p.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) =>
                              ColoredBox(color: scheme.surfaceContainerHighest),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.78),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: _cw(12),
                          right: _cw(12),
                          bottom: _ch(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: _csp(14),
                                    ),
                              ),
                              if (p.subtitle.isNotEmpty) ...[
                                SizedBox(height: _ch(3)),
                                Text(
                                  p.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.white70,
                                        fontSize: _csp(11),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (n > 1) ...[
          SizedBox(height: _ch(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(n, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                margin: EdgeInsets.symmetric(horizontal: _cw(2.5)),
                width: active ? _cw(20) : _cw(6),
                height: _ch(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_cr(8)),
                  color: active ? scheme.primary : scheme.outlineVariant,
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _PropertyNewsStrip extends StatelessWidget {
  const _PropertyNewsStrip({required this.items});

  final List<PropertyNewsSummary> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final n in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              elevation: 1.5,
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push('${AppRoutes.newsDetail}/${n.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            foregroundColor: scheme.onPrimaryContainer,
                            child: const Icon(Icons.newspaper_rounded),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'أخبار العقارات',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  formatPropertyNewsDate(n.publishedAt),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Text(
                        n.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CachedNetworkImage(
                        imageUrl: n.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            ColoredBox(color: scheme.surfaceContainerHighest),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'قراءة الخبر',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PropertySlider extends StatelessWidget {
  const _PropertySlider({required this.items});

  final List<Property> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _ch(356),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => SizedBox(width: _cw(9)),
        itemBuilder: (context, index) {
          final p = items[index];
          return SizedBox(
            width: _cw(214),
            child: PropertyCard(
              property: p,
              onTap: () => context.push('${AppRoutes.propertyDetails}/${p.id}'),
            ),
          );
        },
      ),
    );
  }
}
