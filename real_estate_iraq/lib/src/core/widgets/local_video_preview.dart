import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class LocalVideoPreview extends StatefulWidget {
  const LocalVideoPreview({
    super.key,
    required this.path,
    this.trimStartSeconds,
    this.trimEndSeconds,
    this.showProgress = true,
  });

  final String path;
  final int? trimStartSeconds;
  final int? trimEndSeconds;
  final bool showProgress;

  @override
  State<LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<LocalVideoPreview> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.file(File(widget.path));
    _controller = c;
    try {
      await c.initialize();
      final start = widget.trimStartSeconds;
      if (start != null && start > 0) {
        await c.seekTo(Duration(seconds: start));
      }
      c.addListener(_enforceTrimRange);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _controller = null);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_enforceTrimRange);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LocalVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trimStartSeconds != widget.trimStartSeconds ||
        oldWidget.trimEndSeconds != widget.trimEndSeconds) {
      final c = _controller;
      final start = widget.trimStartSeconds;
      if (c != null && c.value.isInitialized && start != null) {
        c.seekTo(Duration(seconds: start));
      }
    }
  }

  void _enforceTrimRange() {
    final c = _controller;
    final end = widget.trimEndSeconds;
    final start = widget.trimStartSeconds ?? 0;
    if (c == null || end == null || end <= start || !c.value.isInitialized) return;
    if (c.value.position.inSeconds >= end) {
      c.seekTo(Duration(seconds: start));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null || !_ready) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          c.value.isPlaying ? c.pause() : c.play();
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
          if (!c.value.isPlaying)
            const Center(
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.black54,
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
              ),
            ),
          if (widget.showProgress)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(c, allowScrubbing: true),
            ),
        ],
      ),
    );
  }
}
