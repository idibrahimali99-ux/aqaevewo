import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';
import '../api/api_providers.dart';
import 'admin_notification_service.dart';

class AdminNotificationWatcher extends ConsumerStatefulWidget {
  const AdminNotificationWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AdminNotificationWatcher> createState() =>
      _AdminNotificationWatcherState();
}

class _AdminNotificationWatcherState
    extends ConsumerState<AdminNotificationWatcher> {
  Timer? _timer;
  int? _lastUnreadMessages;
  int? _lastPendingOffices;
  int? _lastPendingProperties;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdminNotificationService.instance.init();
      _poll();
      _timer = Timer.periodic(const Duration(seconds: 35), (_) => _poll());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final session = ref.read(adminSessionProvider);
    if (!session.isAuthenticated) return;
    try {
      final data = await ref.read(vewoApiClientProvider).getJson('admin/stats');
      final unread = (data['chat_unread'] as num?)?.toInt() ?? 0;
      final pendingOffices = (data['pending_offices'] as num?)?.toInt() ?? 0;
      final pendingProps = (data['pending_properties'] as num?)?.toInt() ?? 0;
      final prevUnread = _lastUnreadMessages;
      final prevOffices = _lastPendingOffices;
      final prevProps = _lastPendingProperties;
      _lastUnreadMessages = unread;
      _lastPendingOffices = pendingOffices;
      _lastPendingProperties = pendingProps;
      if (prevUnread != null && unread > prevUnread) {
        await AdminNotificationService.instance.show(
          id: 1001,
          title: 'محادثة جديدة',
          body: 'لديك ${unread - prevUnread} رسالة جديدة غير مقروءة.',
          payload: const {'type': 'admin_chat', 'section': 'chats'},
        );
      }
      if (prevOffices != null && pendingOffices > prevOffices) {
        await AdminNotificationService.instance.show(
          id: 1002,
          title: 'مكتب جديد',
          body: 'يوجد طلب مكتب جديد بانتظار الموافقة.',
          payload: const {'type': 'office_pending', 'section': 'offices'},
        );
      }
      if (prevProps != null && pendingProps > prevProps) {
        await AdminNotificationService.instance.show(
          id: 1003,
          title: 'منشور جديد',
          body: 'يوجد منشور جديد بانتظار الموافقة.',
          payload: const {
            'type': 'admin_property_pending',
            'section': 'properties',
          },
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
