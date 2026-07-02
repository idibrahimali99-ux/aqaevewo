import 'package:go_router/go_router.dart';

import '../../routing/admin_routes.dart';

void navigateFromAdminNotificationPayload(
  GoRouter router,
  Map<String, dynamic> data,
) {
  final type = data['type']?.toString() ?? '';
  final section = switch (type) {
    'admin_chat' || 'chat' => 'chats',
    'admin_property_pending' ||
    'property_pending' ||
    'property_created' ||
    'property_updated' => 'properties',
    'admin_reel_pending' || 'reel_pending' => 'reels',
    'property_request' || 'admin_property_request' => 'property_requests',
    'office_pending' || 'admin_office_pending' => 'offices',
    _ => data['section']?.toString(),
  };
  final target = section == null || section.trim().isEmpty
      ? AdminRoutes.console
      : '${AdminRoutes.console}?section=${Uri.encodeComponent(section.trim())}';
  router.go(target);
}
