import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_controller.dart';
import '../api/api_providers.dart';
import 'app_notification_service.dart';

class AppNotificationWatcher extends ConsumerStatefulWidget {
  const AppNotificationWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppNotificationWatcher> createState() =>
      _AppNotificationWatcherState();
}

class _AppNotificationWatcherState
    extends ConsumerState<AppNotificationWatcher> {
  Timer? _timer;
  int? _lastUnreadChats;
  int? _lastReelNewCommentsOnMyReels;
  int? _lastReelNewRepliesToMyComments;
  int? _lastReelNewLikesOnMyComments;
  int? _lastNewSoldCount;
  int? _lastPollMs;
  int? _lastBroadcastPollMs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNotificationService.instance.init();
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
      _poll();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final auth = ref.read(authControllerProvider);
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      // 0) رسائل عامة للجميع (لا تتطلب تسجيل دخول).
      final sinceBroadcast = _lastBroadcastPollMs ?? (nowMs - 70 * 1000);
      try {
        final b = await ref
            .read(vewoApiClientProvider)
            .getJson(
              'app/broadcast/poll',
              query: {'since_ms': '$sinceBroadcast'},
            );
        _lastBroadcastPollMs = nowMs;
        final raw = b['items'];
        if (_lastBroadcastPollMs != null && raw is List) {
          // أول تشغيل: لا نظهر شيء (نمنع الانفجار عند فتح التطبيق أول مرة).
          final first = sinceBroadcast == (nowMs - 70 * 1000);
          if (!first) {
            for (final e in raw) {
              final m = e is Map<String, dynamic>
                  ? e
                  : (e is Map ? Map<String, dynamic>.from(e) : null);
              if (m == null) continue;
              final title = (m['title']?.toString() ?? '').trim();
              final body = (m['body']?.toString() ?? '').trim();
              if (title.isEmpty && body.isEmpty) continue;
              await AppNotificationService.instance.show(
                id: 2100 + (DateTime.now().millisecondsSinceEpoch % 1000),
                title: title.isEmpty ? 'إعلان' : title,
                body: body.isEmpty ? '' : body,
                payload: const {'type': 'broadcast'},
              );
            }
          }
        }
      } catch (_) {}

      if (!auth.isAuthenticated || (auth.apiToken ?? '').isEmpty) {
        _lastUnreadChats = null;
        _lastReelNewCommentsOnMyReels = null;
        _lastReelNewRepliesToMyComments = null;
        _lastReelNewLikesOnMyComments = null;
        _lastNewSoldCount = null;
        _lastPollMs = null;
        return;
      }

      final sinceMs = _lastPollMs ?? (nowMs - 70 * 1000);

      final data = await ref
          .read(vewoApiClientProvider)
          .getJson('app/notifications/poll', query: {'since_ms': '$sinceMs'});

      final counts = data['counts'];
      final m = counts is Map<String, dynamic>
          ? counts
          : (counts is Map ? Map<String, dynamic>.from(counts) : null);
      if (m == null) return;

      final unread = (m['chat_unread'] is num)
          ? (m['chat_unread'] as num).toInt()
          : int.tryParse('${m['chat_unread']}') ?? 0;
      final newComments = (m['reel_new_comments_on_my_reels'] is num)
          ? (m['reel_new_comments_on_my_reels'] as num).toInt()
          : int.tryParse('${m['reel_new_comments_on_my_reels']}') ?? 0;
      final newReplies = (m['reel_new_replies_to_my_comments'] is num)
          ? (m['reel_new_replies_to_my_comments'] as num).toInt()
          : int.tryParse('${m['reel_new_replies_to_my_comments']}') ?? 0;
      final newLikes = (m['reel_new_likes_on_my_comments'] is num)
          ? (m['reel_new_likes_on_my_comments'] as num).toInt()
          : int.tryParse('${m['reel_new_likes_on_my_comments']}') ?? 0;
      final newSold = (m['properties_new_sold'] is num)
          ? (m['properties_new_sold'] as num).toInt()
          : int.tryParse('${m['properties_new_sold']}') ?? 0;

      final prevUnread = _lastUnreadChats;
      final prevComments = _lastReelNewCommentsOnMyReels;
      final prevReplies = _lastReelNewRepliesToMyComments;
      final prevLikes = _lastReelNewLikesOnMyComments;
      final prevSold = _lastNewSoldCount;

      _lastPollMs = nowMs;
      _lastUnreadChats = unread;
      _lastReelNewCommentsOnMyReels = newComments;
      _lastReelNewRepliesToMyComments = newReplies;
      _lastReelNewLikesOnMyComments = newLikes;
      _lastNewSoldCount = newSold;

      // أول مرة: نثبت القيم بدون إظهار إشعارات.
      final firstRun =
          prevUnread == null ||
          prevComments == null ||
          prevReplies == null ||
          prevLikes == null ||
          prevSold == null;
      if (firstRun) return;

      // رسائل المحادثات لها مسارها الخاص عبر FCM وقسم المحادثات، ولا تُضاف
      // إلى إشعارات التطبيق العامة حتى لا تختلط مع أحداث العقارات والريلز.
      if (newComments > prevComments && newComments > 0) {
        await AppNotificationService.instance.show(
          id: 2002,
          title: 'تعليق جديد',
          body: 'لديك تعليقات جديدة على الريلز',
          payload: const {'type': 'reel_comment'},
        );
      }
      if (newReplies > prevReplies && newReplies > 0) {
        await AppNotificationService.instance.show(
          id: 2003,
          title: 'رد جديد',
          body: 'هناك ردود جديدة على تعليقاتك',
          payload: const {'type': 'reel_comment'},
        );
      }
      if (newLikes > prevLikes && newLikes > 0) {
        await AppNotificationService.instance.show(
          id: 2004,
          title: 'إعجاب جديد',
          body: 'هناك إعجابات جديدة على تعليقاتك',
          payload: const {'type': 'reel_like'},
        );
      }
      if (newSold > 0 && newSold != prevSold) {
        await AppNotificationService.instance.show(
          id: 2005,
          title: 'تم البيع',
          body: 'تم تعليم ${newSold == 1 ? 'منشور' : '$newSold منشورات'} كمباع',
          payload: const {'type': 'property_sold'},
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
