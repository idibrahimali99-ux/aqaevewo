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
    'broadcast' || 'reminder' || 'fcm_test' => null,
    _ => data['section']?.toString(),
  };

  final params = <String, String>{
    // يكسر كاش go_router لنفس المسار عند تكرار الإشعار.
    '_n': DateTime.now().millisecondsSinceEpoch.toString(),
  };
  if (section != null && section.trim().isNotEmpty) {
    params['section'] = section.trim();
  } else if ((data['section']?.toString().trim() ?? '').isNotEmpty) {
    params['section'] = data['section'].toString().trim();
  }
  final threadId = data['thread_id']?.toString().trim();
  if (threadId != null && threadId.isNotEmpty) {
    params['section'] = params['section'] ?? 'chats';
    params['thread_id'] = threadId;
  }
  final propertyId = data['property_id']?.toString().trim();
  if (propertyId != null && propertyId.isNotEmpty) {
    params['section'] = params['section'] ?? 'properties';
    params['property_id'] = propertyId;
  }
  final reelId = data['reel_id']?.toString().trim();
  if (reelId != null && reelId.isNotEmpty) {
    params['section'] = params['section'] ?? 'reels';
    params['reel_id'] = reelId;
  }

  final qs = params.entries
      .map(
        (e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');
  router.go('${AdminRoutes.console}?$qs');
}
