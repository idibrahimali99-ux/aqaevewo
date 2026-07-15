import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../../core/notifications/admin_notification_service.dart';
import '../../auth/auth_providers.dart';

typedef AdminNotifCounts = ({
  int chatUnread,
  int pendingOffices,
  int pendingProperties,
});

typedef AdminNotifAcknowledged = Map<String, int>;

/// آخر عدد تم الاطلاع عليه لكل نوع — يُحدَّث فور فتح الإشعار.
final adminNotifAcknowledgedProvider = StateProvider<AdminNotifAcknowledged>(
  (ref) => const {},
);

final adminNotifCountsProvider = FutureProvider.autoDispose<AdminNotifCounts>((
  ref,
) async {
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
    return (
      chatUnread: unread,
      pendingOffices: pendingOffices,
      pendingProperties: pendingProps,
    );
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

int _visibleCount(int current, String key, AdminNotifAcknowledged ack) {
  if (current <= 0) return 0;
  final seen = ack[key] ?? 0;
  return current > seen ? current - seen : 0;
}

int adminNotifVisibleTotal(AdminNotifCounts c, AdminNotifAcknowledged ack) =>
    _visibleCount(c.chatUnread, 'chats', ack) +
    _visibleCount(c.pendingOffices, 'offices', ack) +
    _visibleCount(c.pendingProperties, 'properties', ack);

void acknowledgeAdminNotification(WidgetRef ref, String key, int currentCount) {
  ref.read(adminNotifAcknowledgedProvider.notifier).update((ack) {
    final next = Map<String, int>.from(ack);
    next[key] = currentCount;
    return next;
  });
  ref.invalidate(adminNotifCountsProvider);
}

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  void _open(String key, String target, int currentCount) {
    acknowledgeAdminNotification(ref, key, currentCount);
    Navigator.pop(context, target);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(adminSessionProvider);

    if (!session.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('الإشعارات')),
        body: const Center(child: Text('الرجاء تسجيل الدخول')),
      );
    }

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
      body: AdminNotificationsPanel(onOpenTarget: _open),
    );
  }
}

class AdminNotificationsPanel extends ConsumerWidget {
  const AdminNotificationsPanel({
    super.key,
    required this.onOpenTarget,
  });

  final void Function(String key, String target, int currentCount) onOpenTarget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ack = ref.watch(adminNotifAcknowledgedProvider);
    final async = ref.watch(adminNotifCountsProvider);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface,
            scheme.surfaceContainerHighest.withValues(alpha: 0.42),
          ],
        ),
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text('تعذر تحميل الإشعارات')),
        data: (c) {
          final chatVisible = _visibleCount(c.chatUnread, 'chats', ack);
          final propertiesVisible =
              _visibleCount(c.pendingProperties, 'properties', ack);
          final officesVisible = _visibleCount(c.pendingOffices, 'offices', ack);
          final visibleTotal =
              chatVisible + propertiesVisible + officesVisible;
          if (adminNotifTotal(c) <= 0) {
            return const Center(child: Text('لا توجد إشعارات جديدة'));
          }
          if (visibleTotal <= 0) {
            return const Center(child: Text('تم فتح كل الإشعارات'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'مركز الإشعارات',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  if (visibleTotal > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        visibleTotal > 99 ? '99+' : '$visibleTotal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'تحديث',
                    onPressed: () => ref.invalidate(adminNotifCountsProvider),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (chatVisible > 0)
                _NotificationCard(
                  icon: Icons.forum_outlined,
                  title: 'رسائل غير مقروءة',
                  subtitle: 'افتح المحادثات للرد على المستخدمين بسرعة.',
                  count: chatVisible,
                  onTap: () => onOpenTarget('chats', 'chats', c.chatUnread),
                ),
              if (propertiesVisible > 0)
                _NotificationCard(
                  icon: Icons.article_outlined,
                  title: 'منشورات بانتظار الموافقة',
                  subtitle: 'راجع الصور والبيانات ثم وافق أو ارفض.',
                  count: propertiesVisible,
                  onTap: () =>
                      onOpenTarget('properties', 'properties', c.pendingProperties),
                ),
              if (officesVisible > 0)
                _NotificationCard(
                  icon: Icons.storefront_outlined,
                  title: 'مكاتب بانتظار الموافقة',
                  subtitle: 'تحقق من بيانات المكتب والتفعيل.',
                  count: officesVisible,
                  onTap: () =>
                      onOpenTarget('offices', 'offices', c.pendingOffices),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RedBadge(count: count),
            ],
          ),
        ),
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
