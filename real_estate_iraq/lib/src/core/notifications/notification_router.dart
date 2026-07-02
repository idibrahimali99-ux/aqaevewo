import 'package:go_router/go_router.dart';

import '../../routing/app_routes.dart';

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
        router.push('${AppRoutes.chatRoom}/$tid');
      } else {
        router.push(AppRoutes.chats);
      }
      return;
    case 'property_rejected':
    case 'property_approved':
    case 'property_updated':
    case 'property_sold':
    case 'property_urgent_sale':
      final pid = data['property_id']?.toString().trim();
      if (pid != null && pid.isNotEmpty) {
        router.push('${AppRoutes.propertyDetails}/$pid');
      }
      return;
    case 'reel_comment':
    case 'reel_like':
      final rid = data['reel_id']?.toString().trim();
      if (rid != null && rid.isNotEmpty) {
        router.push('${AppRoutes.reels}?reel_id=$rid');
      } else {
        router.push(AppRoutes.reels);
      }
      return;
    case 'broadcast':
      router.push(AppRoutes.notifications);
      return;
    default:
      if (data['thread_id'] != null) {
        final tid = data['thread_id']?.toString().trim();
        if (tid != null && tid.isNotEmpty) {
          router.push('${AppRoutes.chatRoom}/$tid');
          return;
        }
      }
      router.push(AppRoutes.notifications);
  }
}
