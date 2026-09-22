import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../../core/layout/app_responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../core/widgets/vewo_media_watermark.dart';
import '../../../routing/app_routes.dart';
import '../../../routing/auth_nav.dart';
import '../../auth/data/auth_controller.dart';
import 'reel_create_sheet.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({
    super.key,
    this.openComposer = false,
    this.initialReelId,
    this.ownerId,
    this.includeMine = false,
  });

  final bool openComposer;
  final String? initialReelId;
  final String? ownerId;
  final bool includeMine;

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  final PageController _page = PageController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
      if (!mounted) return;
      _jumpToInitialReel();
      if (widget.openComposer) {
        final auth = ref.read(authControllerProvider);
        if (!auth.isAuthenticated) {
          openLoginScreen(context);
          return;
        }
        final ok = await showReelCreateSheet(context, ref);
        if (ok == true && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم إرسال الريل')));
          await _load();
        }
      }
    });
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ownerId = widget.ownerId?.trim();
      final query = <String, String>{
        if (ownerId != null && ownerId.isNotEmpty) 'owner_id': ownerId,
        if (widget.includeMine) 'include_mine': '1',
        'limit': '80',
      };
      final data = await ref
          .read(vewoApiClientProvider)
          .getJson('reels/list', query: query.isEmpty ? null : query);
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
      final targetId = widget.initialReelId?.trim();
      if (targetId != null &&
          targetId.isNotEmpty &&
          !list.any((e) => e['id']?.toString() == targetId)) {
        try {
          final detail = await ref
              .read(vewoApiClientProvider)
              .getJson('reels/detail', query: {'id': targetId});
          final item = detail['item'];
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final itemOwner = map['owner_user_id']?.toString();
            if (ownerId == null || ownerId.isEmpty || itemOwner == ownerId) {
              list.insert(0, map);
            }
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _index = 0;
      });
      _jumpToInitialReel();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الريلز';
        _loading = false;
      });
    }
  }

  void _jumpToInitialReel() {
    final id = widget.initialReelId?.trim();
    if (id == null || id.isEmpty || _items.isEmpty) return;
    final index = _items.indexWhere((e) => e['id']?.toString() == id);
    if (index <= 0) return;
    _index = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_page.hasClients) return;
      _page.jumpToPage(index);
    });
  }

  String _publisherOf(Map<String, dynamic> row) {
    final raw = row['publisher_display']?.toString().trim() ?? '';
    if (raw.isNotEmpty) return raw;
    final isOffice =
        row['publisher_is_office'] == true ||
        row['publisher_is_office'] == 1 ||
        '${row['publisher_is_office'] ?? ''}' == '1';
    final isMarketer =
        row['publisher_is_marketer'] == true ||
        row['publisher_is_marketer'] == 1 ||
        '${row['publisher_is_marketer'] ?? ''}' == '1';
    if (isOffice || isMarketer) return AppBrandStrings.plainShort;
    return AppBrandStrings.arabicName;
  }

  @override
  Widget build(BuildContext context) {
    final isAuth = ref.watch(authControllerProvider).isAuthenticated;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    )
                  : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد ريلز منشورة بعد',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: PageView.builder(
                        controller: _page,
                        scrollDirection: Axis.vertical,
                        allowImplicitScrolling: true,
                        itemCount: _items.length,
                        onPageChanged: (index) {
                          if (_index == index) return;
                          setState(() => _index = index);
                        },
                        itemBuilder: (context, index) {
                          final row = _items[index];
                          final caption = row['caption']?.toString() ?? '';
                          final propertyId = row['property_id']?.toString();
                          final reelId = row['id']?.toString() ?? '';
                          final likesCount = (row['likes_count'] is num)
                              ? (row['likes_count'] as num).toInt()
                              : int.tryParse(
                                      row['likes_count']?.toString() ?? '0',
                                    ) ??
                                    0;
                          final likedByMe =
                              row['liked_by_me'] == true ||
                              row['liked_by_me'] == 1 ||
                              '${row['liked_by_me'] ?? ''}' == '1';
                          final status =
                              row['approval_status']?.toString() ?? 'approved';
                          final rejectNote =
                              row['reject_note']?.toString().trim() ?? '';
                          final myId =
                              ref.read(authControllerProvider).userId ?? '';
                          final isMine =
                              myId.isNotEmpty &&
                              row['owner_user_id']?.toString() == myId;
                          final canEdit = isMine;
                          return _ReelPage(
                            key: ValueKey(reelId.isEmpty ? 'reel-$index' : reelId),
                            reelId: reelId,
                            videoUrl: row['video_public_url']?.toString() ?? '',
                            title: _publisherOf(row),
                            caption: caption,
                            likesCount: likesCount,
                            likedInitially: likedByMe,
                            canInteract: isAuth && status == 'approved',
                            isActive: index == _index,
                            approvalStatus: status,
                            rejectNote: rejectNote,
                            canEdit: isMine && canEdit,
                            isSold: row['is_sold'] == true ||
                                row['is_sold'] == 1 ||
                                '${row['is_sold'] ?? ''}' == '1',
                            isMine: isMine,
                            onToggleSold: isMine
                                ? (sold) async {
                                    try {
                                      await ref
                                          .read(vewoApiClientProvider)
                                          .postJson('reels/mark-sold', {
                                        'reel_id': reelId,
                                        'is_sold': sold ? 1 : 0,
                                      });
                                      if (!context.mounted) return;
                                      setState(() {
                                        _items[index]['is_sold'] = sold ? 1 : 0;
                                      });
                                    } on VewoApiException catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.message)),
                                      );
                                    }
                                  }
                                : null,
                            onEdit: isMine
                                ? () async {
                              final ok = await showReelCreateSheet(
                                context,
                                ref,
                                existingReel: row,
                              );
                              if (ok != true || !context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم إرسال الريل للمراجعة'),
                                ),
                              );
                              await _load();
                            }
                                : null,
                            onDelete: isMine
                                ? () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('حذف الريل'),
                                        content: const Text(
                                          'سيتم حذف هذا الريل نهائياً. هل أنت متأكد؟',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('إلغاء'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('حذف'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok != true || !context.mounted) return;
                                    try {
                                      await ref
                                          .read(vewoApiClientProvider)
                                          .postJson('reels/delete', {
                                        'id': reelId,
                                      });
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('تم حذف الريل'),
                                        ),
                                      );
                                      await _load();
                                    } on VewoApiException catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(e.message)),
                                      );
                                    }
                                  }
                                : null,
                            onChatOwner: () {
                              final q = <String, String>{
                                if (reelId.isNotEmpty) 'reel_id': reelId,
                                if (propertyId != null &&
                                    propertyId.isNotEmpty)
                                  'property': propertyId,
                              };
                              final qs = q.entries
                                  .map(
                                    (e) =>
                                        '${e.key}=${Uri.encodeComponent(e.value)}',
                                  )
                                  .join('&');
                              context.push(
                                qs.isEmpty
                                    ? '${AppRoutes.chatRoom}/new'
                                    : '${AppRoutes.chatRoom}/new?$qs',
                              );
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelPage extends ConsumerStatefulWidget {
  const _ReelPage({
    super.key,
    required this.reelId,
    required this.videoUrl,
    required this.title,
    required this.caption,
    required this.likesCount,
    required this.likedInitially,
    required this.canInteract,
    required this.onChatOwner,
    required this.isActive,
    this.approvalStatus = 'approved',
    this.rejectNote = '',
    this.canEdit = false,
    this.onEdit,
    this.onDelete,
    this.isSold = false,
    this.isMine = false,
    this.onToggleSold,
  });

  final String reelId;
  final String videoUrl;
  final String title;
  final String caption;
  final int likesCount;
  final bool likedInitially;
  final bool canInteract;
  final VoidCallback onChatOwner;
  final bool isActive;
  final String approvalStatus;
  final String rejectNote;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isSold;
  final bool isMine;
  final Future<void> Function(bool sold)? onToggleSold;

  @override
  ConsumerState<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends ConsumerState<_ReelPage> {
  static const _videoHeaders = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept': '*/*',
  };

  VideoPlayerController? _controller;
  bool _ready = false;
  bool _liked = false;
  int _likes = 0;
  bool _saved = false;
  bool _viewReported = false;
  bool _heartBurst = false;
  int _initAttempt = 0;

  @override
  void initState() {
    super.initState();
    _likes = widget.likesCount;
    _liked = widget.likedInitially;
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final url = widget.videoUrl.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;

    final attempt = ++_initAttempt;
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: _videoHeaders,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted || attempt != _initAttempt) {
        await controller.dispose();
        return;
      }
      setState(() => _ready = true);
      // Re-read isActive after await — page may have become active while loading.
      if (widget.isActive) {
        await controller.play();
        _reportViewOnce();
        if (mounted) setState(() {});
      }
    } catch (_) {
      try {
        await controller.dispose();
      } catch (_) {}
      if (!mounted || attempt != _initAttempt) return;
      if (identical(_controller, controller)) {
        _controller = null;
        _ready = false;
      }
      // Silent auto-retry once (R2 may reject the first request without headers).
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (mounted && attempt == _initAttempt) {
          await _initPlayer();
        }
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didUpdateWidget(covariant _ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposePlayer();
      _ready = false;
      _initAttempt = 0;
      _initPlayer();
      return;
    }
    if (oldWidget.isActive != widget.isActive) {
      final c = _controller;
      if (c == null || !c.value.isInitialized) return;
      if (widget.isActive) {
        c.play();
        _reportViewOnce();
        setState(() {});
      } else {
        c.pause();
        setState(() {});
      }
    }
  }

  Future<void> _disposePlayer() async {
    final c = _controller;
    _controller = null;
    if (c == null) return;
    try {
      await c.pause();
      await c.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    final c = _controller;
    _controller = null;
    c?.dispose();
    super.dispose();
  }

  Future<void> _reportViewOnce() async {
    if (_viewReported || widget.reelId.isEmpty) return;
    if (widget.approvalStatus != 'approved') return;
    _viewReported = true;
    try {
      await ref.read(vewoApiClientProvider).postJson('reels/view', {
        'reel_id': widget.reelId,
      });
    } catch (_) {}
  }

  Future<void> _setLike(bool liked) async {
    if (!widget.canInteract) {
      openLoginScreen(context);
      return;
    }
    if (widget.reelId.isEmpty) return;
    try {
      final data = await ref.read(vewoApiClientProvider).postJson(
        'reels/react',
        {'reel_id': widget.reelId, 'liked': liked ? 1 : 0},
      );
      final lc = data['likes_count'];
      final lm = data['liked_by_me'];
      if (!mounted) return;
      setState(() {
        _liked = lm == true || lm == 1 || '${lm ?? ''}' == '1';
        if (lc is int) {
          _likes = lc;
        } else if (lc is num) {
          _likes = lc.toInt();
        }
      });
    } on VewoApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {}
  }

  Future<void> _onDoubleTapLike() async {
    if (!widget.canInteract) {
      openLoginScreen(context);
      return;
    }
    setState(() => _heartBurst = true);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _heartBurst = false);
    });
    if (!_liked) {
      await _setLike(true);
    } else if (mounted) {
      setState(() => _liked = true);
    }
  }

  void _togglePlayback() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  void _openChat() {
    if (!widget.canInteract) {
      openLoginScreen(context);
      return;
    }
    widget.onChatOwner();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = AppResponsive.shellContentBottomPadding(
      context,
      extra: 4,
    );
    final progressBottom = bottomSafe;
    final soldBarH = widget.isSold ? 42.0 : 0.0;
    final captionBottom = bottomSafe + 52 + soldBarH;
    final actionBottom = bottomSafe + 68;
    final controller = _controller;
    final ready = _ready && controller != null && controller.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (ready)
          GestureDetector(
            onTap: _togglePlayback,
            onDoubleTap: _onDoubleTapLike,
            behavior: HitTestBehavior.opaque,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
        ),
        const VewoReelWatermark(),
        if (widget.isSold)
          Positioned(
            left: 0,
            right: 0,
            bottom: progressBottom + 10,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: const Color(0xFFF5B400),
              child: const Text(
                'تم البيع',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        if (widget.approvalStatus == 'pending' ||
            widget.approvalStatus == 'rejected')
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.approvalStatus == 'rejected'
                    ? Colors.red.withValues(alpha: 0.82)
                    : const Color(0xFFF6B60C).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.approvalStatus == 'rejected'
                          ? 'مرفوض'
                          : 'قيد المراجعة',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (widget.rejectNote.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.rejectNote,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (widget.canEdit && widget.onEdit != null) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: widget.onEdit,
                        child: const Text('تعديل'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        if (_heartBurst)
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1.15),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppColors.mapPin,
                size: 108,
              ),
            ),
          ),
        Positioned(
          left: 16,
          right: 76,
          bottom: captionBottom,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.caption.isEmpty ? 'ريل عقاري' : widget.caption,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
              if (widget.isMine) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.onEdit != null)
                      FilledButton.tonal(
                        onPressed: widget.onEdit,
                        child: const Text('تعديل'),
                      ),
                    if (widget.onDelete != null)
                      FilledButton.tonal(
                        onPressed: widget.onDelete,
                        child: const Text('حذف'),
                      ),
                    if (widget.onToggleSold != null &&
                        widget.approvalStatus == 'approved')
                      FilledButton.tonal(
                        onPressed: () =>
                            widget.onToggleSold!(!widget.isSold),
                        child: Text(
                          widget.isSold ? 'إلغاء تم البيع' : 'تم البيع',
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (ready)
          Positioned(
            left: 14,
            right: 14,
            bottom: progressBottom,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final value = controller.value;
                final duration = value.duration;
                final position = value.position > duration
                    ? duration
                    : value.position;
                final max = duration.inMilliseconds <= 0
                    ? 1.0
                    : duration.inMilliseconds.toDouble();
                final current = position.inMilliseconds
                    .clamp(0, max)
                    .toDouble();
                return Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white30,
                          thumbColor: Colors.white,
                          overlayColor: Colors.white24,
                        ),
                        child: Slider(
                          min: 0,
                          max: max,
                          value: current,
                          onChanged: (v) {
                            controller.seekTo(
                              Duration(milliseconds: v.round()),
                            );
                            setState(() {});
                          },
                        ),
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        Positioned(
          right: 10,
          bottom: actionBottom,
          child: Column(
            children: [
              _ReelAction(
                icon: _liked ? Icons.favorite : Icons.favorite_border,
                color: _liked ? AppColors.mapPin : Colors.white,
                label: '$_likes',
                onTap: () => _setLike(!_liked),
              ),
              _ReelAction(
                icon: _saved ? Icons.bookmark : Icons.bookmark_border,
                label: 'حفظ',
                color: _saved ? AppColors.mapPin : Colors.white,
                onTap: () {
                  if (!widget.canInteract) {
                    openLoginScreen(context);
                    return;
                  }
                  setState(() => _saved = !_saved);
                },
              ),
              const SizedBox(height: 12),
              _ReelAction(
                icon: Icons.near_me_outlined,
                label: 'رسالة',
                onTap: _openChat,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReelAction extends StatelessWidget {
  const _ReelAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final col = Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
    if (onTap == null) return col;
    return InkWell(onTap: onTap, child: col);
  }
}
