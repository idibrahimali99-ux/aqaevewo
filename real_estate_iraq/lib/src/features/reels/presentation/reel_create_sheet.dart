import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/widgets/local_video_preview.dart';
import '../../../core/widgets/vewo_media_watermark.dart';

/// نشر ريل من ورقة سفلية — يُستدعى من زر + في الشريط السفلي أو من شاشة الريلز.
Future<bool?> showReelCreateSheet(BuildContext context, WidgetRef ref) async {
  final captionCtrl = TextEditingController();
  XFile? picked;
  XFile? previewedUploadVideo;
  Duration? duration;
  RangeValues? trimRange;
  bool uploading = false;
  bool previewing = false;
  const mediaTools = MethodChannel('com.aqaevewo.real_estate_iraq/media_tools');

  Future<XFile> trimVideoForUpload(XFile source) async {
    final d = duration;
    final range = trimRange;
    if (d == null || range == null) return source;
    final total = d.inMilliseconds / 1000;
    final start = range.start.clamp(0, total).toDouble();
    final end = range.end.clamp(0, total).toDouble();
    if (start <= 0.2 && end >= total - 0.2) return source;
    if (end - start < 0.1) {
      throw Exception('مدة الفيديو المحددة قصيرة جداً');
    }
    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/vewo_reel_trim_${DateTime.now().microsecondsSinceEpoch}.mp4',
    );
    try {
      await mediaTools.invokeMethod<String>('trimVideo', {
        'inputPath': source.path,
        'outputPath': out.path,
        'startMs': (start * 1000).round(),
        'endMs': (end * 1000).round(),
      });
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'فشل قص الفيديو');
    }
    if (!await out.exists() || await out.length() < 1024) {
      throw Exception('فشل قص الفيديو، حاول اختيار فيديو آخر');
    }
    return XFile(out.path, name: out.uri.pathSegments.last);
  }

  Future<XFile?> previewTrimmedVideo(BuildContext ctx, XFile source) async {
    try {
      final preview = await trimVideoForUpload(source);
      if (!ctx.mounted) return null;
      final ok = await showDialog<bool>(
        context: ctx,
        builder: (_) => _FinalReelPreviewDialog(path: preview.path),
      );
      return ok == true ? preview : null;
    } catch (e) {
      if (!ctx.mounted) return null;
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('تعذر إنشاء المعاينة: $e')));
    }
    return null;
  }

  try {
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
          final sheetHeight = MediaQuery.sizeOf(ctx).height * 0.9;
          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SizedBox(
              height: sheetHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      children: [
                        Text(
                          'نشر ريل جديد',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'اختر الفيديو ثم اسحب طرفي الشريط لتحديد أي جزء تريده بدون مدة ثابتة.',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: uploading
                              ? null
                              : () async {
                                  final x = await ImagePicker().pickVideo(
                                    source: ImageSource.gallery,
                                  );
                                  if (x == null) return;
                                  final vc = VideoPlayerController.file(
                                    File(x.path),
                                  );
                                  try {
                                    await vc.initialize();
                                    final d = vc.value.duration;
                                    setLocal(() {
                                      picked = x;
                                      previewedUploadVideo = null;
                                      duration = d;
                                      trimRange = RangeValues(
                                        0,
                                        d.inMilliseconds / 1000,
                                      );
                                    });
                                  } finally {
                                    await vc.dispose();
                                  }
                                },
                          icon: const Icon(Icons.video_library_outlined),
                          label: Text(
                            picked == null
                                ? 'اختر فيديو'
                                : 'تم الاختيار (${_formatTrimTime((duration?.inMilliseconds ?? 0) / 1000)})',
                          ),
                        ),
                        if (picked != null) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 360),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: AspectRatio(
                                  aspectRatio: 9 / 16,
                                  child: LocalVideoPreview(
                                    path: picked!.path,
                                    trimStartSeconds: trimRange?.start.round(),
                                    trimEndSeconds: trimRange?.end.round(),
                                    showProgress: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (duration != null &&
                              duration!.inMilliseconds > 100) ...[
                            const SizedBox(height: 12),
                            Text(
                              'قص الفيديو',
                              style: Theme.of(ctx).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            _ReelVideoTimelineTrimmer(
                              duration: duration!,
                              values:
                                  trimRange ??
                                  RangeValues(
                                    0,
                                    duration!.inMilliseconds / 1000,
                                  ),
                              enabled: !uploading,
                              onChanged: (v) => setLocal(() {
                                trimRange = v;
                                previewedUploadVideo = null;
                              }),
                            ),
                          ],
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: captionCtrl,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'وصف الريل',
                            hintText: 'اكتب وصفاً مختصراً يظهر تحت الفيديو',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(ctx).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: FilledButton.icon(
                          onPressed: picked == null || uploading || previewing
                              ? null
                              : () async {
                                  var uploadVideo = previewedUploadVideo;
                                  if (uploadVideo == null) {
                                    setLocal(() => previewing = true);
                                    uploadVideo = await previewTrimmedVideo(
                                      ctx,
                                      picked!,
                                    );
                                    if (!ctx.mounted) return;
                                    setLocal(() {
                                      previewedUploadVideo = uploadVideo;
                                      previewing = false;
                                    });
                                    if (uploadVideo == null) return;
                                  }
                                  setLocal(() => uploading = true);
                                  try {
                                    final api = ref.read(vewoApiClientProvider);
                                    final bytes = await uploadVideo
                                        .readAsBytes();
                                    final up = await api.postMultipartBytes(
                                      'properties/upload',
                                      'file',
                                      bytes,
                                      uploadVideo.name.isEmpty
                                          ? 'reel.mp4'
                                          : uploadVideo.name,
                                    );
                                    final url =
                                        up['public_url']?.toString() ?? '';
                                    await api.postJson('reels/create', {
                                      'video_public_url': url,
                                      'caption': captionCtrl.text.trim(),
                                      'comments_enabled': 0,
                                    });
                                    if (ctx.mounted) Navigator.pop(ctx, true);
                                  } catch (e) {
                                    setLocal(() => uploading = false);
                                    if (ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text('تعذر نشر الريل: $e'),
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: uploading || previewing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.publish_rounded),
                          label: Text(
                            uploading
                                ? 'جاري النشر…'
                                : previewing
                                ? 'جاري المعاينة…'
                                : 'نشر',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  } finally {
    captionCtrl.dispose();
  }
}

class _FinalReelPreviewDialog extends StatefulWidget {
  const _FinalReelPreviewDialog({required this.path});

  final String path;

  @override
  State<_FinalReelPreviewDialog> createState() =>
      _FinalReelPreviewDialogState();
}

class _FinalReelPreviewDialogState extends State<_FinalReelPreviewDialog> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..initialize()
          .then((_) async {
            if (!mounted) return;
            _controller.addListener(_tick);
            await _controller.setLooping(true);
            await _controller.play();
            setState(() => _ready = true);
          })
          .catchError((Object e) {
            if (!mounted) return;
            setState(() => _error = 'تعذر تشغيل المعاينة، جرّب فيديو آخر');
          });
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      if (_controller.value.position >= _controller.value.duration) {
        await _controller.seekTo(Duration.zero);
      }
      await _controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  String _time(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'معاينة الريل النهائي قبل النشر',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: !_ready
                    ? ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: _error == null
                              ? const CircularProgressIndicator()
                              : Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                        ),
                      )
                    : GestureDetector(
                        onTap: _togglePlayback,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller.value.size.width,
                                height: _controller.value.size.height,
                                child: VideoPlayer(_controller),
                              ),
                            ),
                            const VewoReelWatermark(),
                            if (!_controller.value.isPlaying)
                              const Center(
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 42,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
            if (_ready) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _togglePlayback,
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      min: 0,
                      max: _controller.value.duration.inMilliseconds
                          .clamp(1, double.infinity)
                          .toDouble(),
                      value: _controller.value.position.inMilliseconds
                          .clamp(
                            0,
                            _controller.value.duration.inMilliseconds.clamp(
                              1,
                              1 << 31,
                            ),
                          )
                          .toDouble(),
                      onChanged: (v) =>
                          _controller.seekTo(Duration(milliseconds: v.round())),
                    ),
                  ),
                  Text(
                    '${_time(_controller.value.position)} / ${_time(_controller.value.duration)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إعادة القص'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _ready
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: const Text('نشر'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTrimTime(double seconds) {
  final d = Duration(milliseconds: (seconds * 1000).round());
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final tenths = (d.inMilliseconds.remainder(1000) / 100).floor();
  return h > 0 ? '$h:$m:$s.$tenths' : '$m:$s.$tenths';
}

class _ReelVideoTimelineTrimmer extends StatelessWidget {
  const _ReelVideoTimelineTrimmer({
    required this.duration,
    required this.values,
    required this.enabled,
    required this.onChanged,
  });

  final Duration duration;
  final RangeValues values;
  final bool enabled;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    final max = (duration.inMilliseconds / 1000)
        .clamp(0.1, double.infinity)
        .toDouble();
    final start = values.start.clamp(0, max).toDouble();
    final end = values.end.clamp(start, max).toDouble();
    final selected = (end - start).clamp(0, max).toDouble();
    final scheme = Theme.of(context).colorScheme;
    const minSelection = 0.1;

    void updateFromDx(double dx, double width) {
      if (!enabled || width <= 0) return;
      final seconds = (dx / width * max).clamp(0, max).toDouble();
      final startDx = width * (start / max);
      final endDx = width * (end / max);
      if ((dx - startDx).abs() <= (dx - endDx).abs()) {
        final nextStart = seconds.clamp(0, end - minSelection).toDouble();
        onChanged(RangeValues(nextStart, end));
      } else {
        final nextEnd = seconds.clamp(start + minSelection, max).toDouble();
        onChanged(RangeValues(start, nextEnd));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 74,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final startX = constraints.maxWidth * (start / max);
              final endX = constraints.maxWidth * (end / max);
              final selectionWidth = (endX - startX).clamp(
                20.0,
                constraints.maxWidth,
              );
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) =>
                    updateFromDx(d.localPosition.dx, constraints.maxWidth),
                onTapDown: (d) =>
                    updateFromDx(d.localPosition.dx, constraints.maxWidth),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: List.generate(
                          22,
                          (i) => Expanded(
                            child: Container(
                              height: 54,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    scheme.surfaceContainerHighest,
                                    scheme.outlineVariant,
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white.withValues(alpha: 0.20),
                                size: i.isEven ? 18 : 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Row(
                        children: [
                          SizedBox(
                            width: startX.clamp(0, constraints.maxWidth),
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.48),
                            ),
                          ),
                          SizedBox(width: selectionWidth),
                          Expanded(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.48),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: startX.clamp(0, constraints.maxWidth).toDouble(),
                      width: selectionWidth,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (startX - 11)
                          .clamp(0, constraints.maxWidth - 22)
                          .toDouble(),
                      child: const _ReelTrimHandle(),
                    ),
                    Positioned(
                      left: (endX - 11)
                          .clamp(0, constraints.maxWidth - 22)
                          .toDouble(),
                      child: const _ReelTrimHandle(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'البداية ${_formatTrimTime(start)} • النهاية ${_formatTrimTime(end)} • المدة ${_formatTrimTime(selected)}',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _ReelTrimHandle extends StatelessWidget {
  const _ReelTrimHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
