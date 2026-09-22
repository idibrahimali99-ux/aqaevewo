import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_providers.dart';
import '../../core/api/vewo_api_client.dart';
import '../../core/media/vewo_image_watermark_burn.dart';
import '../properties/data/properties_providers.dart';
import '../properties/domain/property_category.dart';
import '../properties/domain/property_segment.dart';
import 'publish_transfer.dart';

class PublishQueueState {
  const PublishQueueState({
    this.busy = false,
    this.progress = 0,
    this.label = '',
    this.detail = '',
    this.error,
    this.doneMessage,
  });

  final bool busy;
  final double progress;
  final String label;
  final String detail;
  final String? error;
  final String? doneMessage;

  bool get visible => busy || (doneMessage != null && doneMessage!.isNotEmpty);

  PublishQueueState copyWith({
    bool? busy,
    double? progress,
    String? label,
    String? detail,
    String? error,
    String? doneMessage,
    bool clearError = false,
    bool clearDone = false,
  }) {
    return PublishQueueState(
      busy: busy ?? this.busy,
      progress: progress ?? this.progress,
      label: label ?? this.label,
      detail: detail ?? this.detail,
      error: clearError ? null : (error ?? this.error),
      doneMessage: clearDone ? null : (doneMessage ?? this.doneMessage),
    );
  }
}

class PropertyPublishDraft {
  PropertyPublishDraft({
    required this.isEditing,
    this.editId,
    required this.parcelSimpleFlow,
    required this.pickedImages,
    required this.existingImageUrls,
    this.pickedVideo,
    this.videoTrimStart = 0,
    this.videoTrimEnd,
    this.videoDuration,
    this.existingVideoUrl,
    this.removeExistingVideo = false,
    required this.title,
    required this.governorate,
    required this.addressLine,
    required this.category,
    required this.segment,
    required this.purpose,
    required this.priceIqd,
    required this.areaSqm,
    required this.description,
    required this.detailsJson,
    this.parcelId,
    this.compoundId,
  });

  final bool isEditing;
  final String? editId;
  final bool parcelSimpleFlow;
  final List<XFile> pickedImages;
  final List<String> existingImageUrls;
  final XFile? pickedVideo;
  final double videoTrimStart;
  final double? videoTrimEnd;
  final Duration? videoDuration;
  final String? existingVideoUrl;
  final bool removeExistingVideo;
  final String title;
  final String governorate;
  final String addressLine;
  final PropertyCategory category;
  final PropertySegment segment;
  final String purpose;
  final int priceIqd;
  final int areaSqm;
  final String description;
  final Map<String, dynamic> detailsJson;
  final String? parcelId;
  final String? compoundId;
}

class ReelPublishDraft {
  ReelPublishDraft({
    required this.isEdit,
    this.editingId,
    this.video,
    required this.caption,
  });

  final bool isEdit;
  final String? editingId;
  final XFile? video;
  final String caption;
}

final publishQueueProvider =
    NotifierProvider<PublishQueue, PublishQueueState>(PublishQueue.new);

class PublishQueue extends Notifier<PublishQueueState> {
  Future<void>? _running;

  @override
  PublishQueueState build() => const PublishQueueState();

  void dismiss() {
    if (state.busy) return;
    state = const PublishQueueState();
  }

  Future<void> enqueueProperty(PropertyPublishDraft draft) {
    return _enqueue(
      () => _publishProperty(draft),
      start: 'جاري نشر المنشور…',
    );
  }

  Future<void> enqueueReel(ReelPublishDraft draft) {
    return _enqueue(() => _publishReel(draft), start: 'جاري نشر الريل…');
  }

  Future<void> _enqueue(
    Future<void> Function() work, {
    required String start,
  }) async {
    final previous = _running;
    final current = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      state = PublishQueueState(busy: true, progress: 0.02, label: start);
      await PublishTransferHud.start(start);
      try {
        await work();
      } catch (e) {
        final msg = e is VewoApiException ? e.message : 'تعذر النشر: $e';
        state = PublishQueueState(
          busy: false,
          progress: 0,
          label: '',
          error: msg,
        );
        await PublishTransferHud.fail(msg);
      }
    }();
    _running = current;
    await current;
  }

  void _report(
    double progress,
    String label, {
    int sent = 0,
    int total = 0,
  }) {
    PublishTransferHud.noteBytes(sent);
    final detail = total > 0
        ? '${PublishTransferHud.formatBytes(sent)} / ${PublishTransferHud.formatBytes(total)}  •  ${PublishTransferHud.formatSpeed(PublishTransferHud.bytesPerSecond)}'
        : '';
    state = state.copyWith(
      busy: true,
      progress: progress.clamp(0, 1),
      label: label,
      detail: detail,
      clearError: true,
      clearDone: true,
    );
    PublishTransferHud.progress(
      title: 'رفع المنشور',
      label: label,
      sent: sent,
      total: total,
      fraction: progress,
    );
  }

  Future<void> _publishProperty(PropertyPublishDraft d) async {
    final api = ref.read(vewoApiClientProvider);
    final urls = <String>[...d.existingImageUrls];
    final imageCount = d.pickedImages.length;
    final hasVideo = d.pickedVideo != null && d.pickedVideo!.path.isNotEmpty;
    final prepared = <({Uint8List bytes, String name})>[];

    for (var i = 0; i < d.pickedImages.length; i++) {
      final x = d.pickedImages[i];
      _report(0.03, 'تجهيز الصور ${i + 1}/$imageCount');
      var bytes = await x.readAsBytes();
      if (bytes.isEmpty) continue;
      bytes = await burnVewoWatermarkOnImageBytes(Uint8List.fromList(bytes));
      var name = x.name.trim().isNotEmpty ? x.name : 'img_$i.jpg';
      if (!name.toLowerCase().endsWith('.jpg') &&
          !name.toLowerCase().endsWith('.jpeg')) {
        name = 'img_$i.jpg';
      }
      prepared.add((bytes: bytes, name: name));
    }

    final imageBytesTotal = prepared.fold<int>(0, (a, e) => a + e.bytes.length);
    final sentPerImage = List<int>.filled(prepared.length, 0);
    var imagesDone = 0;

    Future<void> uploadOne(int i) async {
      final item = prepared[i];
      sentPerImage[i] = 0;
      final up = await api.postMultipartBytes(
        'properties/upload',
        'file',
        item.bytes,
        item.name,
        onProgress: (sent, total) {
          sentPerImage[i] = sent;
          final allSent = sentPerImage.fold<int>(0, (a, b) => a + b);
          final frac = imageBytesTotal <= 0
              ? 0.0
              : (allSent / imageBytesTotal) * (hasVideo ? 0.55 : 0.82);
          _report(
            0.05 + frac,
            'رفع الصور ${imagesDone + 1}/$imageCount',
            sent: allSent,
            total: imageBytesTotal,
          );
        },
      );
      final u = up['public_url']?.toString();
      if (u != null && u.isNotEmpty) urls.add(u);
      sentPerImage[i] = item.bytes.length;
      imagesDone++;
    }

    // iOS يفشل كثيراً مع رفع متوازٍ على نفس الـHttpClient
    // (Client is already closed). أندرويد يتحمل 3 عمال.
    final workers = (!kIsWeb && Platform.isIOS) ? 1 : 3;
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final i = next;
        next++;
        if (i >= prepared.length) return;
        await uploadOne(i);
      }
    }

    await Future.wait(
      List.generate(
        prepared.isEmpty ? 0 : (prepared.length < workers ? prepared.length : workers),
        (_) => worker(),
      ),
    );

    if (urls.isEmpty) {
      throw VewoApiException('فشل رفع الصور');
    }

    String? videoUrl = d.isEditing && !d.removeExistingVideo
        ? d.existingVideoUrl
        : null;

    _report(0.93, 'حفظ المنشور');
    final notifier = ref.read(propertyListingsProvider.notifier);
    final res = d.isEditing && (d.editId ?? '').isNotEmpty
        ? await notifier.updateRemote(
            id: d.editId!,
            title: d.title,
            governorate: d.governorate,
            addressLine: d.addressLine,
            category: d.category,
            segment: d.segment,
            purpose: d.purpose,
            detailsJson: d.detailsJson,
            priceIqd: d.priceIqd,
            areaSqm: d.areaSqm,
            description: d.description,
            imageUrls: urls,
            videoUrl: d.parcelSimpleFlow ? null : videoUrl,
            parcelId: d.parcelId,
            compoundId: d.compoundId,
          )
        : await notifier.createRemote(
            title: d.title,
            governorate: d.governorate,
            addressLine: d.addressLine,
            category: d.category,
            segment: d.segment,
            purpose: d.purpose,
            detailsJson: d.detailsJson,
            priceIqd: d.priceIqd,
            areaSqm: d.areaSqm,
            description: d.description,
            imageUrls: urls,
            videoUrl: d.parcelSimpleFlow ? null : videoUrl,
            parcelId: d.parcelId,
            compoundId: d.compoundId,
          );
    if (res.error != null) {
      throw VewoApiException(res.error!);
    }
    final ap = res.approval ?? 'pending';
    final msg = ap == 'approved'
        ? 'تم نشر المنشور ويظهر مباشرة'
        : 'تم الإرسال للمراجعة — سيظهر بعد موافقة الإدارة';
    state = PublishQueueState(
      busy: false,
      progress: 1,
      label: '',
      doneMessage: msg,
    );
    await PublishTransferHud.succeed(msg);
  }

  Future<void> _publishReel(ReelPublishDraft d) async {
    final api = ref.read(vewoApiClientProvider);
    String? url;
    if (d.video != null) {
      _report(0.08, 'رفع فيديو الريل');
      final up = await api.postMultipartFile(
        'properties/upload',
        'file',
        d.video!.path,
        filename: d.video!.name.isEmpty ? 'reel.mp4' : d.video!.name,
        onProgress: (sent, total) {
          if (total <= 0) return;
          _report(
            0.08 + (sent / total) * 0.75,
            'رفع فيديو الريل',
            sent: sent,
            total: total,
          );
        },
      );
      url = up['public_url']?.toString() ?? '';
    }
    _report(0.9, 'حفظ الريل');
    if (d.isEdit && (d.editingId ?? '').isNotEmpty) {
      await api.postJson('reels/update', {
        'id': d.editingId,
        'caption': d.caption,
        if (url != null && url.isNotEmpty) 'video_public_url': url,
      });
      const msg = 'تم إرسال الريل للمراجعة';
      state = const PublishQueueState(
        busy: false,
        progress: 1,
        doneMessage: msg,
      );
      await PublishTransferHud.succeed(msg);
      return;
    }
    if (url == null || url.isEmpty) {
      throw VewoApiException('رابط الفيديو مطلوب');
    }
    await api.postJson('reels/create', {
      'video_public_url': url,
      'caption': d.caption,
      'comments_enabled': 0,
    });
    const msg = 'تم إرسال الريل — يمكنك متابعة التصفح';
    state = const PublishQueueState(
      busy: false,
      progress: 1,
      doneMessage: msg,
    );
    await PublishTransferHud.succeed(msg);
  }
}
