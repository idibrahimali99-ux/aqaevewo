import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';

Future<BitmapDescriptor> createAqarTownMapMarker({
  double size = 56,
  bool selected = false,
}) async {
  try {
    final px = size.round().clamp(48, 128);
    final appIcon = await _loadUiImage(
      'assets/app_icon.png',
      targetWidth: px,
      targetHeight: px,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;
    final center = Offset(size / 2, size * 0.42);
    final radius = size * 0.34;

    paint.color = Colors.black.withValues(alpha: 0.16);
    canvas.drawCircle(center.translate(0, size * 0.09), radius * 1.08, paint);

    paint.color = selected ? AppColors.brandPrimary : AppColors.mapPin;
    canvas.drawCircle(center, radius, paint);

    final pointer = Path()
      ..moveTo(center.dx - radius * 0.36, center.dy + radius * 0.70)
      ..lineTo(center.dx + radius * 0.36, center.dy + radius * 0.70)
      ..lineTo(center.dx, size * 0.94)
      ..close();
    canvas.drawPath(pointer, paint);

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 4 : 3
      ..color = Colors.white.withValues(alpha: selected ? 0.98 : 0.86);
    canvas.drawCircle(center, radius - paint.strokeWidth, paint);
    paint.style = PaintingStyle.fill;

    final iconRadius = radius * 0.72;
    final iconRect = Rect.fromCircle(center: center, radius: iconRadius);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(iconRect, Radius.circular(iconRadius * 0.38)),
    );
    paintImage(
      canvas: canvas,
      rect: iconRect,
      image: appIcon,
      fit: BoxFit.cover,
    );
    canvas.restore();

    final image = await recorder.endRecording().toImage(
      size.round(),
      size.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    appIcon.dispose();
    final raw = bytes?.buffer.asUint8List();
    if (raw == null || raw.isEmpty) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
    return BitmapDescriptor.bytes(raw);
  } catch (_) {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
  }
}

Future<ui.Image> _loadUiImage(
  String asset, {
  int? targetWidth,
  int? targetHeight,
}) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: targetWidth,
    targetHeight: targetHeight,
  );
  final frame = await codec.getNextFrame();
  return frame.image;
}
