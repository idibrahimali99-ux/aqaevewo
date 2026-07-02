import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/app_routes.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../../home/presentation/home_screen.dart';
import '../../properties/presentation/posting_quota_dialog.dart';
import '../../reels/presentation/reel_create_sheet.dart';
import 'publish_options_sheet.dart';

/// شريط سفلي عائم بأسلوب كبسولة حديثة + زر نشر داخل نفس الشريط.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _collapsed = false;

  int _slotFromLocation(String location) {
    if (location.startsWith(AppRoutes.home)) return 0;
    if (location.startsWith(AppRoutes.chats)) return 1;
    if (location.startsWith(AppRoutes.reels)) return 3;
    if (location.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final shouldCollapse = notification.metrics.pixels > 72;
    if (shouldCollapse != _collapsed) {
      setState(() => _collapsed = shouldCollapse);
    }
    return false;
  }

  Future<void> _openReelComposer(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      if (context.mounted) context.push(AppRoutes.login);
      return;
    }
    final ok = await showReelCreateSheet(context, ref);
    if (ok == true && context.mounted) {
      context.go(AppRoutes.reels);
    }
  }

  Future<void> _openPropertyPublish(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authControllerProvider);
    final canPost =
        auth.isAuthenticated &&
        (auth.role == UserRole.office || auth.role == UserRole.customer);
    if (!canPost) {
      if (context.mounted) context.push(AppRoutes.login);
      return;
    }
    if (officePostingQuotaExhausted(
      isOffice: auth.role == UserRole.office,
      postingTrialUnlimited: auth.postingTrialUnlimited,
      postingListingsRemaining: auth.postingListingsRemaining,
    )) {
      if (context.mounted) await showPostingQuotaBlockedDialog(context);
      return;
    }
    if (context.mounted) context.push(AppRoutes.addProperty);
  }

  Future<void> _showPublishMenu(BuildContext context, WidgetRef ref) async {
    await showPublishOptionsSheet(
      context,
      onPostProperty: () => _openPropertyPublish(context, ref),
      onPostReel: () => _openReelComposer(context, ref),
    );
  }

  void _go(BuildContext context, int slot) {
    final location = GoRouterState.of(context).uri.toString();
    if (slot == 0 && location.startsWith(AppRoutes.home)) {
      ref.read(homeRefreshSignalProvider.notifier).state++;
      return;
    }
    switch (slot) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.chats);
        break;
      case 3:
        context.go(AppRoutes.reels);
        break;
      case 4:
        context.go(AppRoutes.profile);
        break;
    }
  }

  void _openSupportChat(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) {
      context.push(AppRoutes.login);
      return;
    }
    context.push('${AppRoutes.chatRoom}/support?support=1');
  }

  Widget _navTile(
    BuildContext context, {
    required int index,
    required int slot,
    required IconData icon,
    required IconData iconSel,
    required String label,
    required VoidCallback onTap,
  }) {
    final sel = slot == index;
    final fg = sel ? AppColors.frameGold : AppColors.navInactive;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Tooltip(
          message: label,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: sel ? (_collapsed ? 46 : 58) : 46,
              height: _collapsed ? 42 : 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: sel
                    ? AppColors.frameGold.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: Icon(
                sel ? iconSel : icon,
                size: _collapsed ? 25 : 28,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _publishTile(BuildContext context, WidgetRef ref) {
    return Expanded(
      child: InkWell(
        onTap: () => _showPublishMenu(context, ref),
        borderRadius: BorderRadius.circular(999),
        child: Tooltip(
          message: 'نشر',
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: _collapsed ? 44 : 52,
              height: _collapsed ? 42 : 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: AppColors.frameGold,
                border: Border.all(
                  color: AppColors.ctaPressed.withValues(alpha: 0.42),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: _collapsed ? 27 : 31,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final slot = _slotFromLocation(location);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final width = MediaQuery.sizeOf(context).width;
    final navWidth = width * (_collapsed ? 0.78 : 0.92);
    final navHeight = _collapsed ? 56.0 : 66.0;
    final bottomGap = bottomInset + (_collapsed ? 8.0 : 12.0);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _handleScroll,
            child: widget.child,
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            left: 18,
            bottom: bottomGap + navHeight + 10,
            child: FloatingActionButton.small(
              heroTag: 'support_chat_fab',
              tooltip: 'الدعم',
              backgroundColor: AppColors.frameGold,
              foregroundColor: Colors.white,
              onPressed: () => _openSupportChat(context, ref),
              child: const Icon(Icons.support_agent_rounded),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            left: (width - navWidth) / 2,
            bottom: bottomGap,
            width: navWidth,
            height: navHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.26),
                    blurRadius: _collapsed ? 18 : 24,
                    offset: Offset(0, _collapsed ? 8 : 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.98),
                    border: Border.all(
                      color: AppColors.borderLight,
                      width: 1.1,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _collapsed ? 8 : 10,
                      vertical: _collapsed ? 6 : 8,
                    ),
                    child: Row(
                      children: [
                        _navTile(
                          context,
                          index: 0,
                          slot: slot,
                          icon: Icons.home_outlined,
                          iconSel: Icons.home_rounded,
                          label: 'الرئيسية',
                          onTap: () => _go(context, 0),
                        ),
                        _navTile(
                          context,
                          index: 3,
                          slot: slot,
                          icon: Icons.play_circle_outline_rounded,
                          iconSel: Icons.play_circle_rounded,
                          label: 'ريلز',
                          onTap: () => _go(context, 3),
                        ),
                        _publishTile(context, ref),
                        _navTile(
                          context,
                          index: 1,
                          slot: slot,
                          icon: Icons.near_me_outlined,
                          iconSel: Icons.near_me_rounded,
                          label: 'الرسائل',
                          onTap: () => _go(context, 1),
                        ),
                        _navTile(
                          context,
                          index: 4,
                          slot: slot,
                          icon: Icons.person_outline_rounded,
                          iconSel: Icons.person_rounded,
                          label: 'حسابي',
                          onTap: () => _go(context, 4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
