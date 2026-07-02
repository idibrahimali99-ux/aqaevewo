import 'package:flutter/material.dart';

import '../data/chat_voice_player.dart';

/// فقاعة صوت مع شريط تقدّم (بث تدريجي).
class VoiceMessageBubble extends StatelessWidget {
  const VoiceMessageBubble({
    super.key,
    required this.player,
    required this.publicUrl,
    required this.color,
    this.durationMs,
    this.streamUrl,
  });

  final ChatVoicePlayer player;
  final String publicUrl;
  final Color color;
  final int? durationMs;
  final String? streamUrl;

  String _formatDuration(int ms) {
    final sec = (ms / 1000).round();
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final active = player.isActiveUrl(publicUrl);
        final buffering = player.isBufferingFor(publicUrl);
        final playing = active && player.playing;
        final progress = player.progressFor(
          publicUrl,
          fallbackDurationMs: durationMs,
        );
        final labelMs = active && player.duration.inMilliseconds > 0
            ? player.duration.inMilliseconds
            : (durationMs ?? 0);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => player.toggle(publicUrl, streamUrl: streamUrl),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: buffering
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          )
                        : Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: color,
                            size: 30,
                          ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 22,
                        child: CustomPaint(
                          painter: _WaveformPainter(
                            progress: progress,
                            color: color,
                            active: active,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        labelMs > 0
                            ? _formatDuration(labelMs)
                            : (playing ? 'جاري التشغيل…' : 'رسالة صوتية'),
                        style: TextStyle(
                          color: color.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.progress,
    required this.color,
    required this.active,
  });

  final double progress;
  final Color color;
  final bool active;

  static const _bars = [0.35, 0.7, 0.5, 0.9, 0.45, 0.75, 0.55, 0.85, 0.4, 0.65];

  @override
  void paint(Canvas canvas, Size size) {
    final n = _bars.length;
    final gap = 3.0;
    final barW = (size.width - gap * (n - 1)) / n;
    final playedBars = (progress * n).floor();

    for (var i = 0; i < n; i++) {
      final h = size.height * _bars[i];
      final x = i * (barW + gap);
      final y = (size.height - h) / 2;
      final played = active && i <= playedBars;
      final paint = Paint()
        ..color = played
            ? color
            : color.withValues(alpha: 0.35)
        ..strokeCap = StrokeCap.round;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barW, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.active != active;
}
