import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/api/api_config.dart';

/// تشغيل صوت المحادثة بتدفّق HTTP (Range) مع تخزين مؤقت أثناء التشغيل.
class ChatVoicePlayer extends ChangeNotifier {
  ChatVoicePlayer() {
    _player.playerStateStream.listen((_) => notifyListeners());
    _player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _player.durationStream.listen((d) {
      if (d != null) {
        _duration = d;
        notifyListeners();
      }
    });
    _player.bufferedPositionStream.listen((_) => notifyListeners());
  }

  final AudioPlayer _player = AudioPlayer();
  String? _activeStreamUrl;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  String? get activeStreamUrl => _activeStreamUrl;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get playing => _player.playing;

  bool isActiveUrl(String publicUrl) =>
      _activeStreamUrl == streamUrlForPublic(publicUrl);

  bool isBufferingFor(String publicUrl) {
    if (!isActiveUrl(publicUrl)) return false;
    final s = _player.processingState;
    return s == ProcessingState.loading || s == ProcessingState.buffering;
  }

  double progressFor(String publicUrl, {int? fallbackDurationMs}) {
    final total = isActiveUrl(publicUrl)
        ? (_duration.inMilliseconds > 0
            ? _duration.inMilliseconds
            : (fallbackDurationMs ?? 0))
        : (fallbackDurationMs ?? 0);
    if (total <= 0) return 0;
    final pos = isActiveUrl(publicUrl) ? _position.inMilliseconds : 0;
    return (pos / total).clamp(0.0, 1.0);
  }

  /// رابط بث يدعم Range عبر `chat/stream`.
  static String streamUrlForPublic(String publicUrl) {
    final trimmed = publicUrl.trim();
    if (trimmed.isEmpty) return trimmed;
    try {
      final uri = Uri.parse(trimmed);
      final name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (name.isNotEmpty &&
          RegExp(r'^[0-9a-fA-F-]{36}\.[a-z0-9]+$', caseSensitive: false)
              .hasMatch(name)) {
        final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
        return '$base/index.php?r=chat/stream&file=${Uri.encodeQueryComponent(name)}';
      }
    } catch (_) {}
    return trimmed;
  }

  static String playbackUrl(String publicUrl, {String? streamUrl}) {
    final s = streamUrl?.trim();
    if (s != null && s.isNotEmpty) return s;
    return streamUrlForPublic(publicUrl);
  }

  Future<void> toggle(String publicUrl, {String? streamUrl}) async {
    final target = playbackUrl(publicUrl, streamUrl: streamUrl);
    if (target.isEmpty) return;

    if (_activeStreamUrl == target) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      notifyListeners();
      return;
    }

    _activeStreamUrl = target;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();

    try {
      await _player.stop();
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(target)),
        preload: true,
      );
      await _player.play();
    } catch (_) {
      _activeStreamUrl = null;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    _activeStreamUrl = null;
    await _player.stop();
    notifyListeners();
  }

  static Future<int?> probeDurationMs(String filePath) async {
    final probe = AudioPlayer();
    try {
      await probe.setFilePath(filePath);
      final d = probe.duration;
      if (d == null || d.inMilliseconds < 1) return null;
      return d.inMilliseconds;
    } catch (_) {
      return null;
    } finally {
      await probe.dispose();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
