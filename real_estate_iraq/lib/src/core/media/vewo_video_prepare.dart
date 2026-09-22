import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

const kReelMinSeconds = 30.0;
const kReelMaxSeconds = 180.0;

const _mediaTools = MethodChannel('com.aqartown.app/media_tools');

/// يجهّز فيديو الرفع: قص اختياري، وعلى iOS تحويل MOV/HEVC إلى MP4.
Future<XFile> prepareVideoForUpload(
  XFile source, {
  Duration? duration,
  double startSeconds = 0,
  double? endSeconds,
  String outputName = 'video.mp4',
}) async {
  final total = (duration?.inMilliseconds ?? 0) / 1000.0;
  final maxEnd = total > 0 ? total : 1e9;
  final end = (endSeconds ?? total).clamp(0, maxEnd).toDouble();
  final start = startSeconds.clamp(0, end).toDouble();
  if (end - start > kReelMaxSeconds + 0.05) {
    throw Exception('مدة الريل يجب ألا تتجاوز 3 دقائق');
  }
  if (end - start + 0.05 < kReelMinSeconds && duration != null && total >= kReelMinSeconds) {
    throw Exception('مدة الريل يجب ألا تقل عن 30 ثانية');
  }
  final needsTrim =
      duration != null && total > 0 && !(start <= 0.2 && end >= total - 0.2);
  if (needsTrim && end - start < 0.1) {
    throw Exception('مدة الفيديو المحددة قصيرة جداً');
  }
  final needsConvert = Platform.isIOS;
  if (!needsTrim && !needsConvert) return source;

  final dir = await getTemporaryDirectory();
  final out = File(
    '${dir.path}/vewo_video_${DateTime.now().microsecondsSinceEpoch}.mp4',
  );
  final startMs = needsTrim ? (start * 1000).round() : 0;
  final endMs = needsTrim
      ? (end * 1000).round()
      : (total > 0 ? (total * 1000).round() : 0);
  try {
    await _mediaTools.invokeMethod<String>('trimVideo', {
      'inputPath': source.path,
      'outputPath': out.path,
      'startMs': startMs,
      'endMs': endMs,
    });
  } on MissingPluginException {
    throw Exception(
      'تحويل فيديو الآيفون غير متوفر في هذه النسخة. حدّث التطبيق ثم أعد المحاولة.',
    );
  } on PlatformException catch (e) {
    throw Exception(e.message ?? 'فشل تجهيز الفيديو للنشر');
  }
  if (!await out.exists() || await out.length() < 1024) {
    throw Exception('فشل تجهيز الفيديو، حاول اختيار فيديو آخر');
  }
  return XFile(out.path, name: outputName, mimeType: 'video/mp4');
}
