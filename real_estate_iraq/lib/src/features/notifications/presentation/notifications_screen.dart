import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/widgets/app_brand_mark.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/notifications/app_notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/app_routes.dart';
import '../../auth/data/auth_controller.dart';

typedef AppNotifCounts = Map<String, int>;

final appNotifCountsProvider = FutureProvider.autoDispose<AppNotifCounts>((
  ref,
) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isAuthenticated) return const {};
  try {
    final api = ref.read(vewoApiClientProvider);
    final data = await api.getJson(
      'app/notifications/poll',
      query: {'since_ms': '0'},
    );
    final c = data['counts'];
    final m = <String, int>{};
    if (c is Map) {
      for (final e in c.entries) {
        final k = e.key.toString();
        final v = e.value;
        final n = (v is num)
            ? v.toInt()
            : int.tryParse(v?.toString() ?? '0') ?? 0;
        m[k] = n;
      }
    }
    return m;
  } catch (_) {
    return const {};
  }
});

final appNotificationsLogProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final auth = ref.watch(authControllerProvider);
      if (!auth.isAuthenticated) return const [];
      try {
        final api = ref.read(vewoApiClientProvider);
        final data = await api.getJson(
          'app/notifications/poll',
          query: {'since_ms': '0'},
        );
        final raw = data['items'];
        final list = <Map<String, dynamic>>[];
        if (raw is List) {
          for (final e in raw) {
            if (e is Map<String, dynamic>) {
              list.add(e);
            } else if (e is Map) {
              list.add(Map<String, dynamic>.from(e));
            }
          }
        }
        return list;
      } catch (_) {
        return const [];
      }
    });

int sumAppNotifCounts(AppNotifCounts m) {
  var s = 0;
  for (final e in m.entries) {
    if (e.key == 'chat_unread') continue;
    final v = e.value;
    if (v > 0) s += v;
  }
  return s;
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final Set<String> _dismissed = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead());
  }

  Future<void> _markAllRead() async {
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated) return;
    try {
      await ref
          .read(vewoApiClientProvider)
          .getJson(
            'app/notifications/poll',
            query: {'since_ms': '0', 'mark_read': '1'},
          );
      ref.invalidate(appNotifCountsProvider);
      ref.invalidate(appNotificationsLogProvider);
    } catch (_) {}
  }

  void _openAndDismiss(String key, VoidCallback open) {
    setState(() => _dismissed.add(key));
    open();
  }

  void _openNotification(Map<String, dynamic> row) {
    final payloadRaw = row['payload'];
    final payload = payloadRaw is Map<String, dynamic>
        ? payloadRaw
        : (payloadRaw is Map
              ? Map<String, dynamic>.from(payloadRaw)
              : const <String, dynamic>{});
    final type = (payload['type'] ?? row['event_type'])?.toString() ?? '';
    final propertyId = payload['property_id']?.toString().trim() ?? '';
    final propRaw = row['property'];
    final property = propRaw is Map<String, dynamic>
        ? propRaw
        : (propRaw is Map
              ? Map<String, dynamic>.from(propRaw)
              : const <String, dynamic>{});
    final editable =
        (property['resubmission_allowed'] is num &&
            (property['resubmission_allowed'] as num).toInt() == 1) ||
        '${property['resubmission_allowed'] ?? ''}' == '1';
    if ((type.startsWith('property_') || type == 'property_sold') &&
        propertyId.isNotEmpty) {
      if ((type == 'property_rejected' || type == 'property_needs_edit') &&
          editable) {
        context.push('${AppRoutes.addProperty}?edit_property_id=$propertyId');
        return;
      }
      context.push('${AppRoutes.propertyDetails}/$propertyId');
      return;
    }
    if (type == 'reel_comment' || type == 'reel_like') {
      context.push(AppRoutes.reels);
      return;
    }
  }

  String _formatDate(String? raw) {
    final d = raw == null ? null : DateTime.tryParse(raw);
    if (d == null) return '';
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}  ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);

    if (!auth.isAuthenticated) {
      return Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: AppBar(title: const AppBarBrandTitle('الإشعارات')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: () => context.push(AppRoutes.login),
              child: const Text('تسجيل الدخول'),
            ),
          ),
        ),
      );
    }

    final async = ref.watch(appNotifCountsProvider);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const AppBarBrandTitle('الإشعارات'),
        actions: [
          IconButton(
            tooltip: 'تفعيل الإشعارات',
            onPressed: () async {
              await AppNotificationService.instance.init();
              ref.invalidate(appNotifCountsProvider);
              ref.invalidate(appNotificationsLogProvider);
            },
            icon: const Icon(Icons.notifications_active_outlined),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              ref.invalidate(appNotifCountsProvider);
              ref.invalidate(appNotificationsLogProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ref
          .watch(appNotificationsLogProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Center(child: Text('تعذر تحميل الإشعارات')),
            data: (items) {
              if (items.isNotEmpty) {
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(appNotificationsLogProvider);
                    ref.invalidate(appNotifCountsProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final row = items[i];
                      final title = row['title']?.toString() ?? 'إشعار';
                      final body = row['body']?.toString() ?? '';
                      final date = _formatDate(row['created_at']?.toString());
                      final unread = (row['read_at']?.toString() ?? '').isEmpty;
                      final propRaw = row['property'];
                      final property = propRaw is Map<String, dynamic>
                          ? propRaw
                          : (propRaw is Map
                                ? Map<String, dynamic>.from(propRaw)
                                : const <String, dynamic>{});
                      final thumb = property['thumb_url']?.toString() ?? '';
                      final publicNo =
                          property['property_public_no']?.toString() ?? '';
                      final status =
                          property['approval_status']?.toString() ?? '';
                      final statusLabel = switch (status) {
                        'approved' => 'تم قبوله',
                        'rejected' => 'تم رفضه',
                        'pending' => 'قيد المراجعة',
                        _ => '',
                      };
                      return ListTile(
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (thumb.isNotEmpty)
                              CircleAvatar(
                                backgroundImage: CachedNetworkImageProvider(
                                  thumb,
                                ),
                              )
                            else
                              Icon(
                                Icons.notifications_active_outlined,
                                color: scheme.primary,
                              ),
                            if (unread)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: AppColors.mapPin,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          [
                            if (publicNo.isNotEmpty || statusLabel.isNotEmpty)
                              [
                                if (publicNo.isNotEmpty) '#$publicNo',
                                if (statusLabel.isNotEmpty) statusLabel,
                              ].join(' · '),
                            if (body.trim().isNotEmpty) body.trim(),
                            if (date.isNotEmpty) date,
                          ].join('\n'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _openNotification(row),
                      );
                    },
                  ),
                );
              }
              return async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    const Center(child: Text('تعذر تحميل الإشعارات')),
                data: (counts) {
                  final total = sumAppNotifCounts(counts);
                  if (total <= 0) {
                    return const Center(child: Text('لا توجد إشعارات جديدة'));
                  }

                  Widget tile({
                    required String keyName,
                    required IconData icon,
                    required String title,
                    required int count,
                    VoidCallback? onTap,
                  }) {
                    if (count <= 0 || _dismissed.contains(keyName)) {
                      return const SizedBox.shrink();
                    }
                    return ListTile(
                      leading: Icon(icon, color: scheme.primary),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: _RedBadge(count: count),
                      onTap: onTap == null
                          ? null
                          : () => _openAndDismiss(keyName, onTap),
                    );
                  }

                  final newComments =
                      counts['reel_new_comments_on_my_reels'] ?? 0;
                  final newReplies =
                      counts['reel_new_replies_to_my_comments'] ?? 0;
                  final newLikes = counts['reel_new_likes_on_my_comments'] ?? 0;
                  final newSold = counts['properties_new_sold'] ?? 0;

                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      tile(
                        keyName: 'reel_new_comments_on_my_reels',
                        icon: Icons.comment_outlined,
                        title: 'تعليقات جديدة على الريلز',
                        count: newComments,
                        onTap: () => context.push(AppRoutes.reels),
                      ),
                      tile(
                        keyName: 'reel_new_replies_to_my_comments',
                        icon: Icons.reply_rounded,
                        title: 'ردود جديدة',
                        count: newReplies,
                        onTap: () => context.push(AppRoutes.reels),
                      ),
                      tile(
                        keyName: 'reel_new_likes_on_my_comments',
                        icon: Icons.thumb_up_outlined,
                        title: 'إعجابات جديدة',
                        count: newLikes,
                        onTap: () => context.push(AppRoutes.reels),
                      ),
                      tile(
                        keyName: 'properties_new_sold',
                        icon: Icons.sell_outlined,
                        title: 'تم البيع',
                        count: newSold,
                        onTap: () => context.push(AppRoutes.profile),
                      ),
                    ].whereType<Widget>().toList(),
                  );
                },
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
        color: AppColors.mapPin,
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
