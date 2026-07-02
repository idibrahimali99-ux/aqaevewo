import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'vewo_media_watermark.dart';

class PropertyVideoPlayer extends StatefulWidget {
  const PropertyVideoPlayer({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.trimStartSeconds,
    this.trimEndSeconds,
  });

  final String url;
  final BoxFit fit;
  final int? trimStartSeconds;
  final int? trimEndSeconds;

  @override
  State<PropertyVideoPlayer> createState() => _PropertyVideoPlayerState();
}

class _PropertyVideoPlayerState extends State<PropertyVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    final c = VideoPlayerController.networkUrl(uri);
    _controller = c;
    try {
      await c.initialize();
      c.setLooping(true);
      final start = widget.trimStartSeconds;
      if (start != null && start > 0) {
        await c.seekTo(Duration(seconds: start));
      }
      c.addListener(_refreshControls);
      c.addListener(_enforceTrimRange);
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _controller = null);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_refreshControls);
    _controller?.removeListener(_enforceTrimRange);
    _controller?.dispose();
    super.dispose();
  }

  void _refreshControls() {
    if (!mounted) return;
    setState(() {});
  }

  void _enforceTrimRange() {
    final c = _controller;
    final end = widget.trimEndSeconds;
    final start = widget.trimStartSeconds ?? 0;
    if (c == null || end == null || end <= start || !c.value.isInitialized) {
      return;
    }
    if (c.value.position.inSeconds >= end) {
      c.seekTo(Duration(seconds: start));
      if (!c.value.isPlaying) {
        setState(() {});
      }
    }
  }

  void _toggle() {
    final c = _controller;
    if (c == null || !_ready) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  Future<void> _seekBy(Duration delta) async {
    final c = _controller;
    if (c == null || !_ready) return;
    final value = c.value;
    final start = Duration(seconds: widget.trimStartSeconds ?? 0);
    final trimEnd = widget.trimEndSeconds;
    final end = trimEnd != null && trimEnd > start.inSeconds
        ? Duration(seconds: trimEnd)
        : value.duration;
    var next = value.position + delta;
    if (next < start) next = start;
    if (next > end) next = end;
    await c.seekTo(next);
  }

  String _formatTime(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final scheme = Theme.of(context).colorScheme;
    if (c == null || !_ready) {
      return ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: scheme.primary)),
      );
    }
    final position = c.value.position;
    final duration = c.value.duration;
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: widget.fit,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
          Positioned.directional(
            textDirection: TextDirection.ltr,
            start: 14,
            top: 14,
            child: const VewoCornerWatermark(width: 92, opacity: 0.40),
          ),
          if (_showControls)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.60),
                    ],
                  ),
                ),
              ),
            ),
          if (_showControls)
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _VideoCircleButton(
                    icon: Icons.replay_10_rounded,
                    onPressed: () => _seekBy(const Duration(seconds: -10)),
                  ),
                  const SizedBox(width: 14),
                  _VideoCircleButton(
                    icon: c.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 62,
                    iconSize: 38,
                    onPressed: _toggle,
                  ),
                  const SizedBox(width: 14),
                  _VideoCircleButton(
                    icon: Icons.forward_10_rounded,
                    onPressed: () => _seekBy(const Duration(seconds: 10)),
                  ),
                ],
              ),
            )
          else if (!c.value.isPlaying)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _showControls ? 1 : 0.15,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    colors: VideoProgressColors(
                      playedColor: scheme.primary,
                      bufferedColor: Colors.white54,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  if (_showControls)
                    Row(
                      children: [
                        Text(
                          _formatTime(position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCircleButton extends StatelessWidget {
  const _VideoCircleButton({
    required this.icon,
    required this.onPressed,
    this.size = 48,
    this.iconSize = 28,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: IconButton.filled(
        style: IconButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.58),
          foregroundColor: Colors.white,
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
      ),
    );
  }
}
