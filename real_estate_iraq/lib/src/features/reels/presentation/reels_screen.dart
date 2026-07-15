import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/layout/app_responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';
import '../../../routing/auth_nav.dart';
import '../../auth/data/auth_controller.dart';
import '../../../core/widgets/vewo_media_watermark.dart';
import 'reel_create_sheet.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({
    super.key,
    this.openComposer = false,
    this.initialReelId,
    this.ownerId,
  });

  /// عند `?compose=1` تُفتح ورقة نشر الريل بعد التحميل.
  final bool openComposer;
  final String? initialReelId;
  final String? ownerId;

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  final PageController _page = PageController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

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
      final data = await ref
          .read(vewoApiClientProvider)
          .getJson(
            'reels/list',
            query: ownerId != null && ownerId.isNotEmpty
                ? {'owner_id': ownerId}
                : null,
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
      final targetId = widget.initialReelId?.trim();
      if (targetId != null &&
          targetId.isNotEmpty &&
          !list.any((e) => e['id']?.toString() == targetId)) {
        try {
          final detail = await ref
              .read(vewoApiClientProvider)
              .getJson('reels/detail', query: {'id': targetId});
          final item = detail['item'];
          if (item is Map<String, dynamic>) {
            final itemOwner = item['owner_user_id']?.toString();
            if (ownerId == null || ownerId.isEmpty || itemOwner == ownerId) {
              list.insert(0, item);
            }
          } else if (item is Map) {
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
      });
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_page.hasClients) return;
      _page.jumpToPage(index);
    });
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
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final row = _items[index];
                          final caption = row['caption']?.toString() ?? '';
                          final publisher =
                              row['publisher_display']?.toString() ??
                              AppBrandStrings.plainShort;
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
                          return _ReelPage(
                            reelId: reelId,
                            videoUrl: row['video_public_url']?.toString() ?? '',
                            title: publisher,
                            caption: caption,
                            likesCount: likesCount,
                            likedInitially: likedByMe,
                            canInteract: isAuth,
                            onChatOwner: () {
                              final q = <String, String>{
                                if (reelId.isNotEmpty) 'reel_id': reelId,
                                if (propertyId != null && propertyId.isNotEmpty)
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
    required this.reelId,
    required this.videoUrl,
    required this.title,
    required this.caption,
    required this.likesCount,
    required this.likedInitially,
    required this.canInteract,
    required this.onChatOwner,
  });

  final String reelId;
  final String videoUrl;
  final String title;
  final String caption;
  final int likesCount;
  final bool likedInitially;
  final bool canInteract;
  final VoidCallback onChatOwner;

  @override
  ConsumerState<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends ConsumerState<_ReelPage> {
  late VideoPlayerController _controller;
  bool _liked = false;
  int _likes = 0;
  bool _saved = false;
  bool _viewReported = false;
  bool _heartBurst = false;

  @override
  void initState() {
    super.initState();
    _likes = widget.likesCount;
    _liked = widget.likedInitially;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) {
          _controller.play();
          setState(() {});
          _reportViewOnce();
        }
      });
  }

  Future<void> _reportViewOnce() async {
    if (_viewReported || widget.reelId.isEmpty) return;
    _viewReported = true;
    try {
      await ref.read(vewoApiClientProvider).postJson('reels/view', {
        'reel_id': widget.reelId,
      });
    } catch (_) {
      // تجاهل فشل تسجيل المشاهدة (شبكة، إلخ)
    }
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
    if (!_controller.value.isInitialized) return;
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  void _openChat() {
    if (!widget.canInteract) {
      openLoginScreen(context);
      return;
    }
    widget.onChatOwner();
  }

  Future<void> _shareReel() async {
    if (widget.reelId.isEmpty) return;
    final link = Uri.parse('${ApiConfig.baseUrl}/index.php')
        .replace(queryParameters: {'r': 'reels/detail', 'id': widget.reelId})
        .toString();
    await SharePlus.instance.share(
      ShareParams(
        text: '${widget.caption.isEmpty ? 'ريل عقاري' : widget.caption}\n$link',
        subject: 'ريل عقاري',
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = AppResponsive.shellContentBottomPadding(
      context,
      extra: 4,
    );
    final progressBottom = bottomSafe;
    final captionBottom = bottomSafe + 52;
    final actionBottom = bottomSafe + 68;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_controller.value.isInitialized)
          GestureDetector(
            onTap: _togglePlayback,
            onDoubleTap: _onDoubleTapLike,
            behavior: HitTestBehavior.opaque,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
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
            ],
          ),
        ),
        if (_controller.value.isInitialized)
          Positioned(
            left: 14,
            right: 14,
            bottom: progressBottom,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final value = _controller.value;
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
                            _controller.seekTo(
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
                icon: Icons.share_outlined,
                label: 'مشاركة',
                onTap: _shareReel,
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
