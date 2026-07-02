import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../../core/notifications/admin_notification_service.dart';
import '../../auth/auth_providers.dart';

typedef AdminNotifCounts = ({int chatUnread, int pendingOffices, int pendingProperties});

final adminNotifCountsProvider = FutureProvider.autoDispose<AdminNotifCounts>((ref) async {
  final session = ref.watch(adminSessionProvider);
  if (!session.isAuthenticated) {
    return (chatUnread: 0, pendingOffices: 0, pendingProperties: 0);
  }
  try {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.getJson('admin/stats');
    final unread = (data['chat_unread'] as num?)?.toInt() ?? 0;
    final pendingOffices = (data['pending_offices'] as num?)?.toInt() ?? 0;
    final pendingProps = (data['pending_properties'] as num?)?.toInt() ?? 0;
    return (chatUnread: unread, pendingOffices: pendingOffices, pendingProperties: pendingProps);
  } on VewoApiException {
    return (chatUnread: 0, pendingOffices: 0, pendingProperties: 0);
  } catch (_) {
    return (chatUnread: 0, pendingOffices: 0, pendingProperties: 0);
  }
});

int adminNotifTotal(AdminNotifCounts c) =>
    (c.chatUnread > 0 ? c.chatUnread : 0) +
    (c.pendingOffices > 0 ? c.pendingOffices : 0) +
    (c.pendingProperties > 0 ? c.pendingProperties : 0);

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends ConsumerState<AdminNotificationsScreen> {
  final Set<String> _dismissed = <String>{};

  void _open(String key, String target) {
    setState(() => _dismissed.add(key));
    Navigator.pop(context, target);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(adminSessionProvider);

    if (!session.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('الإشعارات')),
        body: const Center(child: Text('الرجاء تسجيل الدخول')),
      );
    }

    final async = ref.watch(adminNotifCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            tooltip: 'تفعيل الإشعارات',
            onPressed: () async {
              await AdminNotificationService.instance.init();
              ref.invalidate(adminNotifCountsProvider);
            },
            icon: const Icon(Icons.notifications_active_outlined),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(adminNotifCountsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text('تعذر تحميل الإشعارات')),
        data: (c) {
          final total = adminNotifTotal(c);
          final visibleTotal =
              (_dismissed.contains('chats') ? 0 : c.chatUnread) +
              (_dismissed.contains('properties') ? 0 : c.pendingProperties) +
              (_dismissed.contains('offices') ? 0 : c.pendingOffices);
          if (total <= 0) {
            return const Center(child: Text('لا توجد إشعارات جديدة'));
          }
          if (visibleTotal <= 0) {
            return const Center(child: Text('تم فتح كل الإشعارات'));
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (c.chatUnread > 0 && !_dismissed.contains('chats'))
                ListTile(
                  leading: Icon(Icons.forum_outlined, color: scheme.primary),
                  title: const Text('رسائل غير مقروءة',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  trailing: _RedBadge(count: c.chatUnread),
                  onTap: () => _open('chats', 'chats'),
                ),
              if (c.pendingProperties > 0 && !_dismissed.contains('properties'))
                ListTile(
                  leading: Icon(Icons.article_outlined, color: scheme.primary),
                  title: const Text('منشورات بانتظار الموافقة',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  trailing: _RedBadge(count: c.pendingProperties),
                  onTap: () => _open('properties', 'properties'),
                ),
              if (c.pendingOffices > 0 && !_dismissed.contains('offices'))
                ListTile(
                  leading: Icon(Icons.storefront_outlined, color: scheme.primary),
                  title: const Text('مكاتب بانتظار الموافقة',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  trailing: _RedBadge(count: c.pendingOffices),
                  onTap: () => _open('offices', 'offices'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RedBadge extends StatelessWidget {
  const _RedBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final txt = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        txt,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

