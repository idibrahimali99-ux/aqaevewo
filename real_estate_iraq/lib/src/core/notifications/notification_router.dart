import 'package:go_router/go_router.dart';

import '../../routing/app_routes.dart';

/// يفتح تبويب الشريط السفلي أولاً ثم يدفع الشاشة المطلوبة،
/// حتى يبقى زر الرجوع (أو الشريط السفلي) موجوداً بعد الضغط على أي إشعار.
void _openOverShell(
  GoRouter router, {
  required String shellLocation,
  String? pushLocation,
}) {
  router.go(shellLocation);
  final dest = pushLocation?.trim();
  if (dest == null || dest.isEmpty) return;
  Future<void>.delayed(const Duration(milliseconds: 40), () {
    router.push(dest);
  });
}

void _openPropertyFromNotification(GoRouter router, String pid) {
  _openOverShell(
    router,
    shellLocation: AppRoutes.home,
    pushLocation: '${AppRoutes.propertyDetails}/$pid',
  );
}

/// توجيه المستخدم عند الضغط على إشعار (FCM أو محلي).
void navigateFromNotificationPayload(
  GoRouter router,
  Map<String, dynamic> data,
) {
  final type = data['type']?.toString() ?? '';
  switch (type) {
    case 'chat':
    case 'admin_chat':
      final tid = data['thread_id']?.toString().trim();
      if (tid != null && tid.isNotEmpty) {
        _openOverShell(
          router,
          shellLocation: AppRoutes.chats,
          pushLocation: '${AppRoutes.chatRoom}/$tid',
        );
      } else {
        router.go(AppRoutes.chats);
      }
      return;
    case 'property_rejected':
    case 'property_approved':
    case 'property_updated':
    case 'property_sold':
    case 'property_urgent_sale':
    case 'urgent_sale_public':
      final pid = data['property_id']?.toString().trim();
      if (pid != null && pid.isNotEmpty) {
        _openPropertyFromNotification(router, pid);
      } else {
        router.go(AppRoutes.notifications);
      }
      return;
    case 'property_news':
      final nid = data['news_id']?.toString().trim();
      if (nid != null && nid.isNotEmpty) {
        _openOverShell(
          router,
          shellLocation: AppRoutes.home,
          pushLocation: '${AppRoutes.newsDetail}/$nid',
        );
      } else {
        router.go(AppRoutes.home);
      }
      return;
    case 'home_promotion':
      router.go(AppRoutes.home);
      return;
    case 'reel_comment':
    case 'reel_like':
    case 'reel_approved':
    case 'reel_rejected':
      final rid = data['reel_id']?.toString().trim();
      if (rid != null && rid.isNotEmpty) {
        router.go('${AppRoutes.reels}?reel_id=$rid');
      } else {
        router.go(AppRoutes.reels);
      }
      return;
    case 'broadcast':
    case 'reminder':
    case 'fcm_test':
      router.go(AppRoutes.notifications);
      return;
    case 'property_request':
    case 'property_request_status':
      _openOverShell(
        router,
        shellLocation: AppRoutes.profile,
        pushLocation: AppRoutes.myPropertyRequests,
      );
      return;
    default:
      if (data['thread_id'] != null) {
        final tid = data['thread_id']?.toString().trim();
        if (tid != null && tid.isNotEmpty) {
          _openOverShell(
            router,
            shellLocation: AppRoutes.chats,
            pushLocation: '${AppRoutes.chatRoom}/$tid',
          );
          return;
        }
      }
      if (data['property_id'] != null) {
        final pid = data['property_id']?.toString().trim();
        if (pid != null && pid.isNotEmpty) {
          _openPropertyFromNotification(router, pid);
          return;
        }
      }
      if (data['reel_id'] != null) {
        final rid = data['reel_id']?.toString().trim();
        if (rid != null && rid.isNotEmpty) {
          router.go('${AppRoutes.reels}?reel_id=$rid');
          return;
        }
      }
      router.go(AppRoutes.notifications);
  }
}
