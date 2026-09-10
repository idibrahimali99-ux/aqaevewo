import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/notifications/presentation/admin_notifications_screen.dart';
import '../api/api_providers.dart';
import '../push/admin_fcm_client.dart';
import 'admin_notification_service.dart';

class AdminNotificationWatcher extends ConsumerStatefulWidget {
  const AdminNotificationWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AdminNotificationWatcher> createState() =>
      _AdminNotificationWatcherState();
}

class _AdminNotificationWatcherState
    extends ConsumerState<AdminNotificationWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;
  int? _lastUnreadMessages;
  int? _lastPendingOffices;
  int? _lastPendingProperties;
  int? _lastPendingReels;
  int? _lastPendingRequests;
  int? _lastRecentApproved;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdminNotificationService.instance.init();
      unawaited(_poll());
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_poll());
      unawaited(ref.read(adminFcmBootstrapProvider).start());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) return;
    final session = ref.read(adminSessionProvider);
    if (!session.isAuthenticated) return;
    _polling = true;
    try {
      Map<String, dynamic> data;
      try {
        data = await ref
            .read(vewoApiClientProvider)
            .getJson('admin/notify-pulse');
      } catch (_) {
        data = await ref.read(vewoApiClientProvider).getJson('admin/stats');
      }
      final counts = adminNotifCountsFromJson(data);
      ref.read(adminNotifCountsProvider.notifier).state = counts;
      ref.read(adminNotifLoadedProvider.notifier).state = true;

      final prevUnread = _lastUnreadMessages;
      final prevOffices = _lastPendingOffices;
      final prevProps = _lastPendingProperties;
      final prevReels = _lastPendingReels;
      final prevRequests = _lastPendingRequests;
      final prevApproved = _lastRecentApproved;
      _lastUnreadMessages = counts.chatUnread;
      _lastPendingOffices = counts.pendingOffices;
      _lastPendingProperties = counts.pendingProperties;
      _lastPendingReels = counts.pendingReels;
      _lastPendingRequests = counts.pendingPropertyRequests;
      _lastRecentApproved = counts.recentApprovedProperties;

      final firstRun = prevUnread == null ||
          prevOffices == null ||
          prevProps == null ||
          prevReels == null ||
          prevRequests == null ||
          prevApproved == null;
      if (firstRun) return;

      if (counts.chatUnread > prevUnread) {
        await AdminNotificationService.instance.show(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          title: 'محادثة جديدة',
          body: 'لديك ${counts.chatUnread - prevUnread} رسالة جديدة غير مقروءة.',
          payload: const {'type': 'admin_chat', 'section': 'chats'},
        );
      }
      if (counts.pendingOffices > prevOffices) {
        await AdminNotificationService.instance.show(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          title: 'مكتب جديد',
          body: 'يوجد طلب مكتب جديد بانتظار الموافقة.',
          payload: const {'type': 'office_pending', 'section': 'offices'},
        );
      }
      if (counts.pendingProperties > prevProps) {
        await AdminNotificationService.instance.show(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          title: 'منشور جديد',
          body: 'يوجد منشور جديد بانتظار الموافقة.',
          payload: const {
            'type': 'admin_property_pending',
            'section': 'properties',
          },
        );
      }
      if (counts.recentApprovedProperties > prevApproved) {
        await AdminNotificationService.instance.show(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          title: 'منشور تمت الموافقة عليه',
          body: 'تمت الموافقة على منشور جديد خلال اليوم.',
          payload: const {
            'type': 'admin_property_approved',
            'section': 'properties',
          },
        );
      }
      if (counts.pendingReels > prevReels) {
        await AdminNotificationService.instance.show(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          title: 'ريل جديد',
          body: 'يوجد ريل جديد بانتظار الموافقة.',
          payload: const {'type': 'admin_reel_pending', 'section': 'reels'},
        );
      }
      if (counts.pendingPropertyRequests > prevRequests) {
        await AdminNotificationService.instance.show(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          title: 'طلب عقار جديد',
          body: 'وصل طلب عقار جديد يحتاج متابعة.',
          payload: const {
            'type': 'property_request',
            'section': 'property_requests',
          },
        );
      }
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
