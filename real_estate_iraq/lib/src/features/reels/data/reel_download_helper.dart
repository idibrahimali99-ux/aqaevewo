import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// تنزيل ريل إلى الاستوديو (مع طلب صلاحية التخزين عبر Gal).
Future<void> downloadReelToGallery(
  BuildContext context, {
  required String videoUrl,
  required String reelId,
}) async {
  if (videoUrl.trim().isEmpty) {
    throw Exception('رابط الفيديو غير متاح');
  }
  final uri = Uri.parse(videoUrl);
  final res = await http.get(uri);
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('تعذر تنزيل الفيديو');
  }

  final dir = await getTemporaryDirectory();
  final ext = uri.path.toLowerCase().endsWith('.mp4') ? 'mp4' : 'mp4';
  final path = '${dir.path}/vewo_reel_${reelId.replaceAll('-', '')}.$ext';
  final file = File(path);
  await file.writeAsBytes(res.bodyBytes);
  await Gal.putVideo(path);
  try {
    await file.delete();
  } catch (_) {}
}
