import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../data/chat_voice_player.dart';
import 'reel_context_banner.dart';
import 'voice_message_bubble.dart';
import '../../reels/data/reel_detail_provider.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../../core/layout/app_responsive.dart';
import '../../auth/data/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../../properties/data/properties_providers.dart';
import '../../properties/presentation/property_card.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';
import 'package:go_router/go_router.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.chatId,
    this.propertyId,
    this.fromReelTitle,
    this.reelId,
    this.supportChat = false,
  });

  final String chatId;
  final String? propertyId;

  /// عنوان مختصر عند فتح المحادثة من الريلز (قديم).
  final String? fromReelTitle;

  /// معرّف الريل عند التواصل من قسم الريلز.
  final String? reelId;

  /// محادثة طلب عقار مع الإدارة (بدون منشور).
  final bool supportChat;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = AudioRecorder();
  final _voicePlayer = ChatVoicePlayer();

  String? _threadId;

  /// `direct` = مباشر مع المكتب، `mediated` = عبر المسؤول.
  String? _threadMode;
  int? _threadPublicNo;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _opening = false;
  String? _error;
  Timer? _poll;
  bool _showEmoji = false;
  bool _recording = false;
  bool _recordLocked = false;
  int _recordSeconds = 0;

  Future<void> _saveChatImage(String imageUrl) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          throw Exception('يلزم السماح بالوصول للاستوديو لحفظ الصورة');
        }
      }
      final uri = Uri.parse(imageUrl);
      final res = await http.get(uri);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('تعذر تنزيل الصورة');
      }
      final dir = await getTemporaryDirectory();
      final ext = _imageExtensionFromUrl(uri.path);
      final file = File(
        '${dir.path}/aqar_town_chat_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(res.bodyBytes);
      await Gal.putImage(file.path);
      try {
        await file.delete();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الصورة في الاستوديو')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر حفظ الصورة: $e')));
    }
  }

  String _imageExtensionFromUrl(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.gif')) return 'gif';
    return 'jpg';
  }

  Timer? _recordTimer;
  String? _recordPath;
  final _imagePicker = ImagePicker();

  /// محادثة بوساطة أو مباشرة: تُحدّث دورياً حتى تصل الرسائل للطرفين بسرعة.
  bool _awaitingAdminReply = false;
  String? _customerLastReadAt;
  String? _adminLastReadAt;
  String? _peerTitle;
  Map<String, dynamic>? _reelContext;
  bool get _isNewFlow => widget.chatId == 'new' || widget.chatId == 'support';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final token = ref.read(authControllerProvider).apiToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'انتهت الجلسة. سجّل الخروج ثم الدخول من جديد.';
      });
      return;
    }

    if (_isNewFlow) {
      await _openThread();
    } else {
      _threadId = widget.chatId;
      await _loadMessages();
      _startPoll();
    }
  }

  void _parseThreadPublicNoFromMap(Map<String, dynamic> data) {
    final tpnRaw = data['thread_public_no'];
    final tpn = tpnRaw is num
        ? tpnRaw.toInt()
        : int.tryParse(tpnRaw?.toString() ?? '');
    if (tpn != null && tpn > 0) {
      setState(() => _threadPublicNo = tpn);
    }
  }

  Future<void> _openThread() async {
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final body = <String, dynamic>{};
      final pid = widget.propertyId?.trim();
      if (pid != null && pid.isNotEmpty) {
        body['property_id'] = pid;
      }
      final rid = widget.reelId?.trim();
      if (rid != null && rid.isNotEmpty) {
        body['reel_id'] = rid;
      }
      final data = await api.postJson('chat/thread/open', body);
      final tid = data['thread_id']?.toString();
      if (tid == null || tid.isEmpty) {
        throw VewoApiException('استجابة غير متوقعة من السيرفر');
      }
      final mode = data['thread_mode']?.toString();
      final tpnRaw = data['thread_public_no'];
      final tpn = tpnRaw is num
          ? tpnRaw.toInt()
          : int.tryParse(tpnRaw?.toString() ?? '');
      final reelRaw = data['reel'];
      Map<String, dynamic>? reelCtx;
      if (reelRaw is Map<String, dynamic>) {
        reelCtx = reelRaw;
      } else if (reelRaw is Map) {
        reelCtx = Map<String, dynamic>.from(reelRaw);
      }
      if (!mounted) return;
      setState(() {
        _threadId = tid;
        _threadMode = mode;
        if (tpn != null && tpn > 0) _threadPublicNo = tpn;
        _peerTitle = _peerTitleFromResponse(data);
        _reelContext = reelCtx;
        _opening = false;
        _loading = false;
      });
      await _loadMessages();
      _startPoll();
      if (widget.supportChat) {
        // رسالة افتتاحية مختصرة لطلب عقار (best-effort).
        try {
          await _sendRaw('مرحباً، أريد طلب عقار.');
        } catch (_) {}
      }
    } on VewoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _opening = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر بدء المحادثة';
        _opening = false;
        _loading = false;
      });
    }
  }

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_threadId != null) {
        _loadMessages(silent: true);
      }
    });
  }

  Future<void> _loadMessages({bool silent = false}) async {
    final tid = _threadId;
    if (tid == null) return;
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson(
        'chat/messages',
        query: {'thread_id': tid},
      );
      _parseThreadPublicNoFromMap(data);
      final awaiting = data['awaiting_admin_reply'] == true;
      final raw = data['items'];
      final list = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            list.add(e);
          } else if (e is Map) {
            list.add(Map<String, dynamic>.from(e));
          }
        }
      }
      final reelRaw = data['reel'];
      Map<String, dynamic>? reelCtx;
      if (reelRaw is Map<String, dynamic>) {
        reelCtx = reelRaw;
      } else if (reelRaw is Map) {
        reelCtx = Map<String, dynamic>.from(reelRaw);
      }
      if (!mounted) return;
      setState(() {
        _awaitingAdminReply = awaiting;
        _customerLastReadAt = data['customer_last_read_at']?.toString();
        _adminLastReadAt = data['admin_last_read_at']?.toString();
        _peerTitle = _peerTitleFromResponse(data) ?? _peerTitle;
        _messages = list;
        if (reelCtx != null) _reelContext = reelCtx;
        if (!silent) _loading = false;
      });
      _scrollToEnd();
      // mark read when loaded successfully
      await _markRead();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted || silent) return;
      setState(() {
        _error = 'تعذر تحميل الرسائل';
        _loading = false;
      });
    }
  }

  String? _peerTitleFromResponse(Map<String, dynamic> data) {
    final auth = ref.read(authControllerProvider);
    final myId = auth.userId ?? '';
    final customerId = data['customer_user_id']?.toString() ?? '';
    final officeId = data['office_user_id']?.toString() ?? '';
    final candidates = <String>[];
    if (officeId == myId) {
      candidates.add(data['customer_display_name']?.toString() ?? '');
    } else if (customerId == myId) {
      candidates.add(data['office_display_name']?.toString() ?? '');
    }
    candidates.addAll([
      data['peer'] is Map
          ? ((data['peer'] as Map)['full_name']?.toString() ?? '')
          : '',
      data['admin'] is Map
          ? ((data['admin'] as Map)['full_name']?.toString() ?? '')
          : '',
      data['office_display_name']?.toString() ?? '',
      data['customer_display_name']?.toString() ?? '',
    ]);
    for (final candidate in candidates) {
      final value = candidate.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendRaw(String text) async {
    final tid = _threadId;
    if (tid == null) return;
    final api = ref.read(vewoApiClientProvider);
    await api.postJson('chat/messages', {'thread_id': tid, 'body': text});
    await _loadMessages(silent: true);
  }

  DateTime? _parseReadTs(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  bool _seenByInquirerAndAdmin(Map<String, dynamic> msg) {
    if (_threadMode != 'mediated') return false;
    final created = _parseReadTs(msg['created_at']?.toString());
    if (created == null) return false;
    final cust = _parseReadTs(_customerLastReadAt);
    final adm = _parseReadTs(_adminLastReadAt);
    if (cust == null || adm == null) return false;
    return !cust.isBefore(created) && !adm.isBefore(created);
  }

  bool _showSeenForMyMessage(Map<String, dynamic> msg, bool isMe) {
    if (!isMe) return false;
    final auth = ref.read(authControllerProvider);
    final role = auth.role;
    final created = _parseReadTs(msg['created_at']?.toString());
    if (created == null) return false;
    if (role == UserRole.customer || role == UserRole.office) {
      final adm = _parseReadTs(_adminLastReadAt);
      return adm != null && !adm.isBefore(created);
    }
    if (role == UserRole.admin) {
      final cust = _parseReadTs(_customerLastReadAt);
      return cust != null && !cust.isBefore(created);
    }
    return _seenByInquirerAndAdmin(msg);
  }

  Future<void> _markRead() async {
    final tid = _threadId;
    if (tid == null) return;
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('chat/thread/read', {'thread_id': tid});
    } catch (_) {
      // ignore
    }
  }

  Future<void> _toggleEmoji() async {
    setState(() => _showEmoji = !_showEmoji);
    if (_showEmoji) {
      FocusScope.of(context).unfocus();
    }
  }

  void _tickRecordTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_recording) return;
      setState(() => _recordSeconds++);
    });
  }

  Future<void> _startRecord() async {
    if (_recording) return;
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('صلاحية الميكروفون مطلوبة')),
        );
      }
      return;
    }
    final dir = Directory.systemTemp;
    final path =
        '${dir.path}/vewo_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    setState(() {
      _recording = true;
      _recordLocked = false;
      _recordSeconds = 0;
      _recordPath = path;
    });
    _tickRecordTimer();
  }

  Future<void> _cancelRecord() async {
    if (!_recording) return;
    _recordTimer?.cancel();
    await _recorder.stop();
    setState(() {
      _recording = false;
      _recordLocked = false;
      _recordSeconds = 0;
      _recordPath = null;
    });
  }

  Future<void> _stopRecordAndSend() async {
    if (!_recording) return;
    _recordTimer?.cancel();
    final recordedSec = _recordSeconds;
    final path = await _recorder.stop();
    setState(() {
      _recording = false;
      _recordLocked = false;
      _recordSeconds = 0;
    });
    final p = path ?? _recordPath;
    if (p == null) return;
    final f = File(p);
    if (!await f.exists()) return;
    final bytes = await f.readAsBytes();
    if (bytes.isEmpty) return;

    try {
      final api = ref.read(vewoApiClientProvider);
      final ext = p.toLowerCase().endsWith('.m4a') ? 'm4a' : 'aac';
      final up = await api.postMultipartBytes(
        'chat/upload',
        'file',
        bytes,
        'voice.$ext',
      );
      final url = up['public_url']?.toString();
      if (url == null || url.isEmpty) throw Exception('upload failed');
      final durationMs =
          await ChatVoicePlayer.probeDurationMs(p) ??
          (recordedSec > 0 ? recordedSec * 1000 : null);
      final tid = _threadId;
      if (tid == null) return;
      await api.postJson('chat/messages', {
        'thread_id': tid,
        'media_type': 'audio',
        'media_public_url': url,
        if (durationMs != null && durationMs > 0) 'duration_ms': durationMs,
      });
      await _loadMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر إرسال الصوت: $e')));
      }
    }
  }

  Future<void> _sendText() async {
    final t = _controller.text.trim();
    if (t.isEmpty || _threadId == null) return;
    _controller.clear();
    try {
      await _sendRaw(t);
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر إرسال الرسالة')));
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_threadId == null) return;
    try {
      final x = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.isEmpty) return;
      final api = ref.read(vewoApiClientProvider);
      final name = x.name.trim().isNotEmpty ? x.name : 'chat.jpg';
      final up = await api.postMultipartBytes(
        'chat/upload',
        'file',
        bytes,
        name,
      );
      final url = up['public_url']?.toString();
      if (url == null || url.isEmpty) throw Exception('upload failed');
      await api.postJson('chat/messages', {
        'thread_id': _threadId,
        'media_type': 'image',
        'media_public_url': url,
      });
      await _loadMessages(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر إرسال الصورة: $e')));
      }
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _recordTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    _recorder.dispose();
    _voicePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authControllerProvider).userId;
    final threadNo = _threadPublicNo;
    final title = _peerTitle?.trim().isNotEmpty == true
        ? _peerTitle!.trim()
        : (_isNewFlow ? AppBrandStrings.plainShort : 'محادثة');

    final propertyId = widget.propertyId;
    final propAsync = propertyId != null && propertyId.isNotEmpty
        ? ref.watch(propertyDetailProvider(propertyId))
        : null;
    final reelId = widget.reelId?.trim();
    final reelAsync =
        (_reelContext == null && reelId != null && reelId.isNotEmpty)
        ? ref.watch(reelDetailProvider(reelId))
        : null;
    final reelMap = _reelContext ?? reelAsync?.valueOrNull;

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 22,
              width: 68,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AppBrandMark(
                  variant: AppBrandMarkVariant.compact,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(title),
            if (threadNo != null)
              Text(
                '#$threadNo',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            if (widget.propertyId != null && widget.propertyId!.isNotEmpty)
              Text(
                'بخصوص إعلان: ${widget.propertyId}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            if (widget.fromReelTitle != null &&
                widget.fromReelTitle!.trim().isNotEmpty)
              Text(
                widget.fromReelTitle!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
          ],
        ),
      ),
      body: _opening || (_loading && _messages.isEmpty && _error == null)
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _threadId == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : Column(
              children: [
                if (reelMap != null) ReelContextBanner(reel: reelMap),
                if (propAsync != null)
                  propAsync.when(
                    loading: () => const SizedBox(height: 4),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (p) {
                      if (p == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                        child: SizedBox(
                          height: 120,
                          child: PropertyCard(
                            property: p,
                            onTap: () => context.push(
                              '${AppRoutes.propertyDetails}/${p.id}',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                if (_awaitingAdminReply)
                  Material(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.mark_chat_unread_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'في انتظار ردّ الإدارة — ستظهر المحادثة هنا بعد أول رد من الفريق.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _loadMessages(),
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final sid = m['sender_user_id']?.toString();
                        final isMe = myId != null && sid == myId;
                        final body = m['body']?.toString() ?? '';
                        final senderRole = m['sender_role']?.toString() ?? '';
                        final senderName =
                            senderRole == 'admin' || senderRole == 'staff'
                            ? AppBrandStrings.plainShort
                            : (m['sender_display_name']?.toString() ?? '');
                        final senderLabel =
                            senderRole == 'admin' || senderRole == 'staff'
                            ? ''
                            : (m['sender_conversation_label']?.toString() ??
                                  '');
                        final mediaType = m['media_type']?.toString() ?? 'none';
                        final mediaUrl =
                            m['media_public_url']?.toString() ?? '';
                        final durationMsRaw = m['duration_ms'];
                        final durationMs = durationMsRaw is num
                            ? durationMsRaw.toInt()
                            : int.tryParse('$durationMsRaw');
                        final align = isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft;
                        final cs = Theme.of(context).colorScheme;
                        final bg = isMe ? cs.primary : cs.surfaceContainerHigh;
                        final fg = isMe ? cs.onPrimary : cs.onSurface;
                        return Align(
                          alignment: align,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                            ),
                            child: Card(
                              color: bg,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe && senderName.isNotEmpty) ...[
                                      Text(
                                        senderLabel.isEmpty
                                            ? senderName
                                            : '$senderName · $senderLabel',
                                        style: TextStyle(
                                          color: fg.withValues(alpha: 0.8),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    if (mediaType == 'image' &&
                                        mediaUrl.isNotEmpty)
                                      GestureDetector(
                                        onTap: () => showDialog<void>(
                                          context: context,
                                          barrierColor: Colors.black,
                                          builder: (ctx) => Dialog.fullscreen(
                                            backgroundColor: Colors.black,
                                            child: SafeArea(
                                              child: Stack(
                                                children: [
                                                  Center(
                                                    child: InteractiveViewer(
                                                      minScale: 1,
                                                      maxScale: 4,
                                                      child: Image.network(
                                                        mediaUrl,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  ),
                                                  PositionedDirectional(
                                                    top: 8,
                                                    start: 8,
                                                    child: IconButton.filled(
                                                      tooltip: 'حفظ الصورة',
                                                      onPressed: () =>
                                                          _saveChatImage(
                                                            mediaUrl,
                                                          ),
                                                      icon: const Icon(
                                                        Icons.download_rounded,
                                                      ),
                                                    ),
                                                  ),
                                                  PositionedDirectional(
                                                    top: 8,
                                                    end: 8,
                                                    child: IconButton.filled(
                                                      tooltip: 'إغلاق',
                                                      onPressed: () =>
                                                          Navigator.pop(ctx),
                                                      icon: const Icon(
                                                        Icons.close_rounded,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Image.network(
                                            mediaUrl,
                                            width: 220,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (c, child, prog) {
                                              if (prog == null) return child;
                                              return SizedBox(
                                                width: 220,
                                                height: 140,
                                                child: Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: fg,
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    if (mediaType == 'audio' &&
                                        mediaUrl.isNotEmpty)
                                      VoiceMessageBubble(
                                        player: _voicePlayer,
                                        publicUrl: mediaUrl,
                                        color: fg,
                                        durationMs: durationMs,
                                      ),
                                    if (body.isNotEmpty)
                                      Text(
                                        body,
                                        style: TextStyle(
                                          color: fg,
                                          height: 1.35,
                                        ),
                                      ),
                                    if (_showSeenForMyMessage(m, isMe)) ...[
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'تمت المشاهدة',
                                          style: TextStyle(
                                            color: fg.withValues(alpha: 0.75),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom > 0
                        ? 8
                        : AppResponsive.shellContentBottomPadding(
                            context,
                            extra: 0,
                          ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_recording)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  _recordLocked
                                      ? Icons.lock_rounded
                                      : Icons.mic_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatRecordTime(_recordSeconds),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                if (_recordLocked)
                                  TextButton(
                                    onPressed: _threadId == null
                                        ? null
                                        : _stopRecordAndSend,
                                    child: const Text('إرسال'),
                                  ),
                                IconButton(
                                  tooltip: 'إلغاء',
                                  onPressed: _cancelRecord,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'إيموجي',
                              onPressed: _toggleEmoji,
                              icon: const Icon(Icons.emoji_emotions_outlined),
                            ),
                            IconButton(
                              tooltip: 'صورة',
                              onPressed: _threadId == null
                                  ? null
                                  : _pickAndSendImage,
                              icon: const Icon(Icons.image_outlined),
                            ),
                            GestureDetector(
                              onLongPressStart: _threadId == null
                                  ? null
                                  : (_) => _startRecord(),
                              onLongPressEnd: _threadId == null
                                  ? null
                                  : (_) {
                                      if (_recordLocked) return;
                                      _stopRecordAndSend();
                                    },
                              onLongPressMoveUpdate: _threadId == null
                                  ? null
                                  : (d) {
                                      if (d.localOffsetFromOrigin.dy < -72) {
                                        if (!_recordLocked) {
                                          setState(() => _recordLocked = true);
                                        }
                                      }
                                    },
                              child: IconButton(
                                tooltip:
                                    'اضغط مطولاً للتسجيل — اسحب للأعلى للقفل',
                                onPressed: _recording && _recordLocked
                                    ? _stopRecordAndSend
                                    : null,
                                icon: Icon(
                                  _recording
                                      ? Icons.stop_circle_outlined
                                      : Icons.mic_none_rounded,
                                  color: _recording
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: _recording
                                      ? 'جاري التسجيل…'
                                      : 'اكتب رسالة…',
                                ),
                                onSubmitted: (_) => _sendText(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _threadId == null ? null : _sendText,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.all(12),
                                minimumSize: const Size(48, 48),
                              ),
                              child: const Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                        if (_showEmoji)
                          SizedBox(
                            height: 280,
                            child: EmojiPicker(
                              textEditingController: _controller,
                              config: const Config(
                                checkPlatformCompatibility: true,
                                emojiViewConfig: EmojiViewConfig(
                                  emojiSizeMax: 28,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatRecordTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
