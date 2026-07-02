import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/admin_theme_mode_provider.dart';
import '../../routing/admin_routes.dart';
import '../auth/auth_providers.dart';
import '../chat/presentation/admin_chats_screen.dart';
import '../dashboard/presentation/admin_overview_tab.dart';
import '../offices/presentation/admin_offices_screen.dart';
import '../governorates/presentation/admin_governorates_screen.dart';
import '../news/presentation/admin_property_news_screen.dart';
import '../promotions/presentation/admin_home_promotions_screen.dart';
import '../properties/presentation/admin_properties_screen.dart';
import '../parcels/presentation/admin_parcels_screen.dart';
import '../compounds/presentation/admin_compounds_screen.dart';
import '../reels/presentation/admin_reels_screen.dart';
import '../requests/presentation/admin_property_requests_screen.dart';
import '../settings/presentation/admin_settings_screen.dart';
import '../users/presentation/admin_users_screen.dart';
import '../notifications/presentation/admin_notifications_screen.dart';
import '../marketers/presentation/admin_marketers_screen.dart';
import '../marketers/presentation/admin_posting_packages_screen.dart';

/// هيكل اللوحة: شريط تنقّل جانبي على الشاشات العريضة، وقائمة منزلقة على الصغيرة.
class AdminConsoleScreen extends ConsumerStatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  ConsumerState<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends ConsumerState<AdminConsoleScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;
  String? _lastSectionParam;

  bool _canAccessDest(WidgetRef ref, _NavDest d) {
    final session = ref.read(adminSessionProvider);
    if (d.permission == null) return true;
    if (d.permission == 'reels') {
      return session.canAccess('reels') || session.canAccess('properties');
    }
    return session.canAccess(d.permission!);
  }

  static const _destinations = <_NavDest>[
    _NavDest(Icons.dashboard_rounded, 'نظرة عامة', null),
    _NavDest(Icons.campaign_outlined, 'إعلانات الرئيسية', 'promotions'),
    _NavDest(Icons.newspaper_rounded, 'أخبار العقارات', 'news'),
    _NavDest(Icons.storefront_outlined, 'مكاتب', 'offices'),
    _NavDest(Icons.map_outlined, 'محافظات', 'settings'),
    _NavDest(Icons.grid_view_rounded, 'مقاطعات', 'parcels'),
    _NavDest(Icons.location_city_outlined, 'مجمعات سكنية', 'parcels'),
    _NavDest(Icons.article_outlined, 'منشورات', 'properties'),
    _NavDest(Icons.video_collection_outlined, 'ريلز', 'reels'),
    _NavDest(Icons.assignment_outlined, 'طلبات العقار', 'properties'),
    _NavDest(Icons.forum_outlined, 'محادثات', 'chats'),
    _NavDest(Icons.people_outline_rounded, 'مستخدمون', 'users'),
    _NavDest(Icons.badge_outlined, 'مسوقون', 'users'),
    _NavDest(Icons.inventory_2_outlined, 'باقات النشر', 'users'),
    _NavDest(Icons.settings_outlined, 'إعدادات', 'settings'),
  ];

  void _select(int i) {
    final permission = _destinations[i].permission;
    if (permission != null && !_canAccessDest(ref, _destinations[i])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا تملك صلاحية دخول هذا القسم')),
      );
      return;
    }
    setState(() => _index = i);
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _applySectionParam(BuildContext context) {
    final section = GoRouterState.of(context).uri.queryParameters['section'];
    if (section == null || section == _lastSectionParam) return;
    _lastSectionParam = section;
    final target = switch (section) {
      'chats' => 10,
      'properties' => 7,
      'property_requests' => 9,
      'offices' => 3,
      'reels' => 8,
      'users' => 11,
      _ => null,
    };
    if (target == null || target == _index) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _select(target);
    });
  }

  Widget _page(int i) {
    return switch (i) {
      0 => AdminOverviewTab(onOpenSection: _select),
      1 => const AdminHomePromotionsScreen(),
      2 => const AdminPropertyNewsScreen(),
      3 => const AdminOfficesScreen(),
      4 => const AdminGovernoratesScreen(),
      5 => const AdminParcelsScreen(),
      6 => const AdminCompoundsScreen(),
      7 => const AdminPropertiesScreen(),
      8 => const AdminReelsScreen(),
      9 => const AdminPropertyRequestsScreen(),
      10 => const AdminChatsScreen(),
      11 => const AdminUsersScreen(),
      12 => const AdminMarketersScreen(),
      13 => const AdminPostingPackagesScreen(),
      14 => const AdminSettingsScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  Future<bool> _handleBack() async {
    if (_index != 0) {
      setState(() => _index = 0);
      return false;
    }
    return false; // لا نخرج من التطبيق عند الرجوع في شاشة الكونسل
  }

  Future<void> _logout() async {
    await ref.read(adminSessionProvider).signOut();
    if (!mounted) return;
    context.go(AdminRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    _applySectionParam(context);
    final session = ref.watch(adminSessionProvider);
    final scheme = Theme.of(context).colorScheme;
    final adminThemeMode = ref.watch(adminThemeModeProvider);
    final themeController = ref.read(adminThemeModeProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        final visibleDestinations = [
          for (var i = 0; i < _destinations.length; i++)
            if (_destinations[i].permission == null ||
                _canAccessDest(ref, _destinations[i]))
              MapEntry(i, _destinations[i]),
        ];
        final visibleSelectedIndex = visibleDestinations.indexWhere(
          (entry) => entry.key == _index,
        );
        final effectiveIndex = visibleSelectedIndex < 0 ? 0 : _index;
        final rail = NavigationRail(
          extended: wide,
          selectedIndex: visibleSelectedIndex < 0 ? 0 : visibleSelectedIndex,
          onDestinationSelected: (visibleIndex) =>
              _select(visibleDestinations[visibleIndex].key),
          labelType: wide
              ? NavigationRailLabelType.none
              : NavigationRailLabelType.selected,
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
            child: Icon(
              Icons.shield_moon_outlined,
              color: scheme.primary,
              size: 32,
            ),
          ),
          destinations: [
            for (final entry in visibleDestinations)
              NavigationRailDestination(
                icon: Icon(entry.value.icon),
                selectedIcon: Icon(entry.value.icon, color: scheme.primary),
                label: Text(entry.value.label),
              ),
          ],
        );

        final body = ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.topCenter,
                children: <Widget>[...previousChildren, ?currentChild],
              );
            },
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.02, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(effectiveIndex),
              child: _page(effectiveIndex),
            ),
          ),
        );

        final appBar = AppBar(
          title: Text(_destinations[effectiveIndex].label),
          leading: wide
              ? null
              : IconButton(
                  tooltip: 'الأقسام',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: 'الإشعارات',
              onPressed: () async {
                final res = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const AdminNotificationsScreen(),
                  ),
                );
                if (!mounted || res == null) return;
                if (res == 'chats') _select(9);
                if (res == 'properties') _select(7);
                if (res == 'offices') _select(3);
              },
              icon: ref
                  .watch(adminNotifCountsProvider)
                  .when(
                    loading: () => const Icon(Icons.notifications_none_rounded),
                    error: (_, _) =>
                        const Icon(Icons.notifications_none_rounded),
                    data: (c) {
                      final total = adminNotifTotal(c);
                      if (total <= 0) {
                        return const Icon(Icons.notifications_none_rounded);
                      }
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_none_rounded),
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                total > 99 ? '99+' : '$total',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
            ),
            IconButton(
              tooltip: '${themeController.label} — اضغط للتبديل',
              onPressed: themeController.toggle,
              icon: Icon(
                adminThemeMode == ThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
            ),
            IconButton(
              tooltip: 'تلقائي حسب النهار والليل',
              onPressed: themeController.setAuto,
              icon: const Icon(Icons.schedule_rounded),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Chip(
                avatar: Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                label: Text(
                  session.fullName ?? 'admin',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
                backgroundColor: scheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
              ),
            ),
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
            ),
            const SizedBox(width: 4),
          ],
        );

        final shell = wide
            ? Scaffold(
                body: Row(
                  children: [
                    rail,
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: scheme.outline.withValues(alpha: 0.25),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          appBar,
                          Expanded(child: body),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : Scaffold(
                key: _scaffoldKey,
                appBar: appBar,
                drawer: Drawer(
                  child: SafeArea(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      children: [
                        const ListTile(
                          title: Text(
                            'الأقسام',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        for (final entry in visibleDestinations)
                          ListTile(
                            leading: Icon(entry.value.icon),
                            title: Text(entry.value.label),
                            selected: entry.key == _index,
                            onTap: () => _select(entry.key),
                          ),
                      ],
                    ),
                  ),
                ),
                body: body,
              );

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            await _handleBack();
          },
          child: shell,
        );
      },
    );
  }
}

class _NavDest {
  const _NavDest(this.icon, this.label, this.permission);
  final IconData icon;
  final String label;
  final String? permission;
}
