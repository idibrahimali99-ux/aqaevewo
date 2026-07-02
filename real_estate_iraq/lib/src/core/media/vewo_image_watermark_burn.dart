import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

import '../widgets/vewo_media_watermark.dart';

/// يدمج العلامة المائية في ملف الصورة قبل الرفع (حرق دائم).
Future<Uint8List> burnVewoWatermarkOnImageBytes(
  Uint8List input, {
  int? propertyCode,
}) async {
  if (input.isEmpty) return input;

  ui.Image? source;
  ui.Image? watermark;
  try {
    final codec = await ui.instantiateImageCodec(input);
    final frame = await codec.getNextFrame();
    source = frame.image;
    final w = source.width;
    final h = source.height;
    if (w < 1 || h < 1) return input;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );
    canvas.drawImage(source, Offset.zero, Paint());

    canvas.save();
    canvas.translate(w / 2.0, h / 2.0);
    canvas.rotate(-0.42);

    watermark = await _loadWatermarkAsset();
    if (watermark != null) {
      final wmWidth = (w * 0.42).clamp(120, 520).toDouble();
      final wmHeight = wmWidth * watermark.height / watermark.width;
      final dst = Rect.fromCenter(
        center: Offset.zero,
        width: wmWidth,
        height: wmHeight,
      );
      canvas.drawImageRect(
        watermark,
        Rect.fromLTWH(
          0,
          0,
          watermark.width.toDouble(),
          watermark.height.toDouble(),
        ),
        dst,
        Paint()
          ..isAntiAlias = true
          ..color = Colors.white.withValues(alpha: 0.38),
      );
    } else {
      final baseSize = w * 0.16;
      _paintWmLine(
        canvas,
        VewoMediaWatermark.brandLine,
        fontSize: baseSize,
        yOffset: -baseSize * 0.35,
        opacity: 0.38,
      );
      _paintWmLine(
        canvas,
        VewoMediaWatermark.supportPhone,
        fontSize: baseSize * 0.5,
        yOffset: baseSize * 0.15,
        opacity: 0.36,
      );
      if (propertyCode != null && propertyCode > 0) {
        _paintWmLine(
          canvas,
          '#$propertyCode',
          fontSize: baseSize * 0.58,
          yOffset: baseSize * 0.55,
          opacity: 0.34,
        );
      }
    }
    canvas.restore();

    final picture = recorder.endRecording();
    final raster = await picture.toImage(w, h);
    final bd = await raster.toByteData(format: ui.ImageByteFormat.png);
    raster.dispose();
    if (bd == null) return input;

    final pngBytes = bd.buffer.asUint8List();
    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) return pngBytes;
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 88));
  } catch (_) {
    return input;
  } finally {
    source?.dispose();
    watermark?.dispose();
  }
}

Future<ui.Image?> _loadWatermarkAsset() async {
  try {
    final data = await rootBundle.load(VewoMediaWatermark.assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

void _paintWmLine(
  Canvas canvas,
  String text, {
  required double fontSize,
  required double yOffset,
  required double opacity,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: GoogleFonts.tajawal(
        fontSize: fontSize.clamp(14, 48),
        fontWeight: FontWeight.w900,
        color: VewoMediaWatermark.wmColor.withValues(
          alpha: opacity.clamp(0.22, 0.55),
        ),
      ),
    ),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
  )..layout();
  tp.paint(canvas, Offset(-tp.width / 2, yOffset - tp.height / 2));
}
