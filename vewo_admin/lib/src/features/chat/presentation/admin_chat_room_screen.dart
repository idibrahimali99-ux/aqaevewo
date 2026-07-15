import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/admin_theme.dart';
import '../data/chat_voice_player.dart';
import 'voice_message_bubble.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../auth/auth_providers.dart';
import '../../users/presentation/admin_user_profile_screen.dart';
import 'admin_chat_property_detail_sheet.dart';

class AdminChatRoomScreen extends ConsumerStatefulWidget {
  const AdminChatRoomScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<AdminChatRoomScreen> createState() =>
      _AdminChatRoomScreenState();
}

class _AdminChatRoomScreenState extends ConsumerState<AdminChatRoomScreen> {
  final _controller = TextEditingController();
  final _scrollDirect = ScrollController();
  final _voicePlayer = ChatVoicePlayer();
  final _audioRecorder = AudioRecorder();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;
  Timer? _poll;
  String _sendMode = 'customer_only';
  int _mediatedLaneTab = 0;
  int? _threadPublicNo;
  String _threadType = 'mediated';
  Map<String, dynamic>? _property;
  Map<String, dynamic>? _reel;
  String? _customerDisplayName;
  String? _customerPhone;
  String? _officeDisplayName;
  String? _officePhone;
  String? _customerUserId;
  String? _officeUserId;
  bool _customerCaughtUp = false;
  String? _threadLastMessageAt;
  final Set<String> _heartMessageIds = {};
  bool _recording = false;
  String? _recordingPath;

  Future<void> _saveChatImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final res = await http.get(uri);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('تعذر تنزيل الصورة');
      }
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory(
        '${dir.path}${Platform.pathSeparator}chat_images',
      );
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      final ext = _imageExtensionFromUrl(uri.path);
      final file = File(
        '${folder.path}${Platform.pathSeparator}aqar_town_chat_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(res.bodyBytes);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم حفظ الصورة: ${file.path}')));
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _poll = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _load(silent: true),
      );
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _controller.dispose();
    _scrollDirect.dispose();
    _audioRecorder.dispose();
    _voicePlayer.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final api = ref.read(vewoApiClientProvider);
      final data = await api.getJson(
        'chat/messages',
        query: {'thread_id': widget.threadId},
      );
      final tpnRaw = data['thread_public_no'];
      final tpn = tpnRaw is num
          ? tpnRaw.toInt()
          : int.tryParse(tpnRaw?.toString() ?? '');
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
      if (!mounted) return;
      setState(() {
        _messages = list;
        if (tpn != null && tpn > 0) _threadPublicNo = tpn;
        _threadType = data['thread_type']?.toString() ?? _threadType;
        _customerUserId = data['customer_user_id']?.toString().trim();
        _officeUserId = data['office_user_id']?.toString().trim();
        _customerDisplayName = data['customer_display_name']?.toString().trim();
        _officeDisplayName = data['office_display_name']?.toString().trim();
        _customerPhone = data['customer_phone']?.toString().trim();
        _officePhone = data['office_phone']?.toString().trim();
        final caught = data['mediated_customer_caught_up'];
        _customerCaughtUp = caught == true || caught == 1 || caught == '1';
        _threadLastMessageAt = data['thread_last_message_at']?.toString();
        final prop = data['property'];
        _property = prop is Map<String, dynamic>
            ? prop
            : prop is Map
            ? Map<String, dynamic>.from(prop)
            : null;
        final reel = data['reel'];
        _reel = reel is Map<String, dynamic>
            ? reel
            : reel is Map
            ? Map<String, dynamic>.from(reel)
            : null;
        if ((_customerUserId?.isNotEmpty ?? false) &&
            (_officeUserId?.isNotEmpty ?? false)) {
          _sendMode = _mediatedLaneTab == 0 ? 'customer_only' : 'office_only';
        } else if (_threadType == 'direct') {
          _sendMode = 'all';
        } else {
          _sendMode = _mediatedLaneTab == 0 ? 'customer_only' : 'office_only';
        }
        if (!silent) _loading = false;
      });
      await _markRead();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollDirect.hasClients) {
          _scrollDirect.jumpTo(_scrollDirect.position.maxScrollExtent);
        }
      });
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
        _error = 'تعذر التحميل';
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    _controller.clear();
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('chat/messages', {
        'thread_id': widget.threadId,
        'body': t,
        'visibility': _sendMode,
      });
      await _load(silent: true);
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _markRead() async {
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('chat/thread/read', {'thread_id': widget.threadId});
    } catch (_) {}
  }

  Future<void> _copy(String? text, String okLabel) async {
    final t = text?.trim() ?? '';
    if (t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(okLabel)));
  }

  Future<void> _openWa(String? phone) async {
    final uri = whatsappUriFromIraqPhone(phone ?? '');
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم الهاتف غير صالح لواتساب')),
      );
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح الواتساب — انسخ الرقم يدوياً')),
      );
    }
  }

  bool get _useMediatedTabs =>
      (_threadType == 'mediated' || _threadType == 'direct') &&
      (_customerUserId != null && _customerUserId!.isNotEmpty) &&
      (_officeUserId != null && _officeUserId!.isNotEmpty);

  bool _msgCustomerTab(Map<String, dynamic> m) {
    final sid = m['sender_user_id']?.toString() ?? '';
    final vis = m['visibility']?.toString() ?? 'all';
    final cid = _customerUserId ?? '';
    final oid = _officeUserId ?? '';
    if (sid == cid) return true;
    if (sid == oid) return false;
    if (vis == 'customer_only') return true;
    if (vis == 'office_only') return false;
    return vis == 'all';
  }

  bool _msgOfficeTab(Map<String, dynamic> m) {
    final sid = m['sender_user_id']?.toString() ?? '';
    final vis = m['visibility']?.toString() ?? 'all';
    final cid = _customerUserId ?? '';
    final oid = _officeUserId ?? '';
    if (sid == oid) return true;
    if (sid == cid) return false;
    if (vis == 'office_only') return true;
    if (vis == 'customer_only') return false;
    return false;
  }

  bool _msgInActiveTab(Map<String, dynamic> m) {
    if (!_useMediatedTabs) return true;
    return _mediatedLaneTab == 0 ? _msgCustomerTab(m) : _msgOfficeTab(m);
  }

  List<Map<String, dynamic>> _visibleSorted() {
    final list = _messages.where(_msgInActiveTab).toList();
    list.sort(
      (a, b) => (a['created_at']?.toString() ?? '').compareTo(
        b['created_at']?.toString() ?? '',
      ),
    );
    return list;
  }

  String _formatMsgTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _startRecording() async {
    if (_recording) return;
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فعّل إذن الميكروفون من إعدادات التطبيق'),
          ),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/admin_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordingPath = path;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر بدء التسجيل')));
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_recording) return;
    final savedPath = _recordingPath;
    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordingPath = null;
    });
    final filePath = (path != null && path.isNotEmpty) ? path : savedPath;
    if (filePath == null || !File(filePath).existsSync()) {
      return;
    }
    try {
      final api = ref.read(vewoApiClientProvider);
      final up = await api.postMultipartFile('chat/upload', 'file', filePath);
      final url = up['public_url']?.toString() ?? '';
      if (url.isEmpty) {
        throw Exception('no url');
      }
      final durationMs = await ChatVoicePlayer.probeDurationMs(filePath) ?? 0;
      await api.postJson('chat/messages', {
        'thread_id': widget.threadId,
        'body': '',
        'visibility': _sendMode,
        'media_type': 'audio',
        'media_public_url': url,
        if (durationMs > 0) 'duration_ms': durationMs,
      });
      try {
        await File(filePath).delete();
      } catch (_) {}
      await _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر إرسال الصوت: $e')));
    }
  }

  Widget _buildMessagesArea(String? myId) {
    final list = _useMediatedTabs ? _visibleSorted() : _messages;
    return ListView.builder(
      controller: _scrollDirect,
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final m = list[i];
        return _bubbleAligned(m, myId);
      },
    );
  }

  Widget _bubbleAligned(Map<String, dynamic> m, String? myId) {
    final sid = m['sender_user_id']?.toString();
    final isMe = myId != null && sid == myId;
    final mid = m['id']?.toString() ?? '';
    final created = m['created_at']?.toString();
    final vis = m['visibility']?.toString() ?? 'all';
    final showSeen =
        isMe &&
        _threadType == 'mediated' &&
        _mediatedLaneTab == 0 &&
        vis == 'customer_only' &&
        _customerCaughtUp;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.88,
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _MsgBubble(
                m: m,
                isMe: isMe,
                threadType: _threadType,
                voicePlayer: _voicePlayer,
                timeLabel: _formatMsgTime(created),
                showSeenByCustomer: showSeen,
                heart: mid.isNotEmpty && _heartMessageIds.contains(mid),
                onToggleHeart: mid.isEmpty
                    ? null
                    : () => setState(() {
                        if (_heartMessageIds.contains(mid)) {
                          _heartMessageIds.remove(mid);
                        } else {
                          _heartMessageIds.add(mid);
                        }
                      }),
                onCopy: () async {
                  final t = m['body']?.toString().trim() ?? '';
                  if (t.isEmpty) return;
                  await _copy(t, 'تم النسخ');
                },
                onSaveImage: _saveChatImage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(adminSessionProvider).userId;
    final tpn = _threadPublicNo;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _threadType == 'direct'
                  ? 'محادثة مباشرة'
                  : 'محادثة — مستفسر ومعلن',
            ),
            if (tpn != null)
              Text(
                '#$tpn',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            if (_threadLastMessageAt != null &&
                _threadLastMessageAt!.trim().isNotEmpty)
              Text(
                'آخر نشاط: ${_formatMsgTime(_threadLastMessageAt)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          if (_threadType != 'direct' &&
              ((_customerPhone != null && _customerPhone!.isNotEmpty) ||
                  (_officePhone != null && _officePhone!.isNotEmpty)))
            PopupMenuButton<String>(
              tooltip: 'نسخ وأرقام',
              icon: const Icon(Icons.content_copy_rounded),
              onSelected: (v) async {
                if (v == 'cc') {
                  await _copy(_customerPhone, 'تم نسخ رقم المستفسر');
                } else if (v == 'co') {
                  await _copy(_officePhone, 'تم نسخ رقم المعلن');
                } else if (v == 'wc') {
                  await _openWa(_customerPhone);
                } else if (v == 'wo') {
                  await _openWa(_officePhone);
                }
              },
              itemBuilder: (ctx) => [
                if (_customerPhone != null && _customerPhone!.isNotEmpty) ...[
                  const PopupMenuItem(
                    value: 'cc',
                    child: ListTile(
                      leading: Icon(Icons.person_outline_rounded),
                      title: Text('نسخ رقم المستفسر'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'wc',
                    child: ListTile(
                      leading: Icon(
                        Icons.chat_rounded,
                        color: Color(0xFF25D366),
                      ),
                      title: const Text('واتساب المستفسر'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
                if (_officePhone != null && _officePhone!.isNotEmpty) ...[
                  const PopupMenuItem(
                    value: 'co',
                    child: ListTile(
                      leading: Icon(Icons.storefront_outlined),
                      title: Text('نسخ رقم المعلن'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'wo',
                    child: ListTile(
                      leading: Icon(
                        Icons.chat_rounded,
                        color: Color(0xFF25D366),
                      ),
                      title: const Text('واتساب المعلن'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
      body: _loading && _messages.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                if (_property != null)
                  _PropertySummaryCard(property: _property!),
                if (_reel != null) _ReelSummaryCard(reel: _reel!),
                if (_useMediatedTabs)
                  _MediatedPartiesCard(
                    customerName: _customerDisplayName,
                    customerPhone: _customerPhone,
                    officeName: _officeDisplayName,
                    officePhone: _officePhone,
                  ),
                if (_useMediatedTabs)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          icon: Icon(Icons.person_outline_rounded),
                          label: Text('المستفسر'),
                        ),
                        ButtonSegment(
                          value: 1,
                          icon: Icon(Icons.storefront_outlined),
                          label: Text('المعلن'),
                        ),
                      ],
                      selected: {_mediatedLaneTab},
                      onSelectionChanged: (s) {
                        final i = s.first;
                        setState(() {
                          _mediatedLaneTab = i;
                          _sendMode = i == 0 ? 'customer_only' : 'office_only';
                        });
                      },
                    ),
                  ),
                Expanded(child: SelectionArea(child: _buildMessagesArea(myId))),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              hintText: 'رد… (نسخ ولصق مدعوم)',
                            ),
                            minLines: 1,
                            maxLines: 6,
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        FilledButton(
                          onPressed: _send,
                          child: const Icon(Icons.send_rounded),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onLongPressStart: (_) => _startRecording(),
                          onLongPressEnd: (_) =>
                              unawaited(_stopRecordingAndSend()),
                          child: IconButton.filledTonal(
                            tooltip: 'اضغط مطولاً لتسجيل صوت',
                            icon: Icon(
                              _recording
                                  ? Icons.mic_rounded
                                  : Icons.mic_none_rounded,
                              color: _recording ? Colors.red : null,
                            ),
                            onPressed: () {},
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
}

class _MsgBubble extends StatelessWidget {
  const _MsgBubble({
    required this.m,
    required this.isMe,
    required this.threadType,
    required this.voicePlayer,
    required this.timeLabel,
    required this.showSeenByCustomer,
    required this.heart,
    this.onToggleHeart,
    required this.onCopy,
    required this.onSaveImage,
  });

  final Map<String, dynamic> m;
  final bool isMe;
  final String threadType;
  final ChatVoicePlayer voicePlayer;
  final String timeLabel;
  final bool showSeenByCustomer;
  final bool heart;
  final VoidCallback? onToggleHeart;
  final VoidCallback onCopy;
  final Future<void> Function(String imageUrl) onSaveImage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = m['body']?.toString() ?? '';
    final fn = m['sender_full_name']?.toString().trim() ?? '';
    final dn = m['sender_display_name']?.toString().trim() ?? '';
    final senderName = fn.isNotEmpty ? fn : dn;
    final senderLabel = m['sender_conversation_label']?.toString().trim() ?? '';
    final avatar = m['sender_avatar_url']?.toString().trim() ?? '';
    final visibility = m['visibility']?.toString() ?? 'all';
    final mediaType = m['media_type']?.toString() ?? 'none';
    final mediaUrl = m['media_public_url']?.toString() ?? '';
    final durationMsRaw = m['duration_ms'];
    final durationMs = durationMsRaw is num
        ? durationMsRaw.toInt()
        : int.tryParse('$durationMsRaw');

    final cardColor = isMe ? scheme.primary : AdminTheme.surfaceHighDark;
    final fg = isMe ? AdminTheme.textPrimary : Colors.white70;

    final card = Card(
      color: cardColor,
      margin: EdgeInsets.zero,
      child: InkWell(
        onLongPress: onCopy,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white24,
                        backgroundImage: avatar.isNotEmpty
                            ? CachedNetworkImageProvider(avatar)
                            : null,
                        child: avatar.isEmpty
                            ? Icon(Icons.person_outline, size: 20, color: fg)
                            : null,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe && senderName.isNotEmpty)
                          Text(
                            senderLabel.isEmpty
                                ? senderName
                                : '$senderName · $senderLabel',
                            style: TextStyle(
                              color: fg.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        if (!isMe && senderName.isNotEmpty)
                          const SizedBox(height: 4),
                        if (isMe && visibility != 'all')
                          Text(
                            visibility == 'office_only'
                                ? '→ للمعلن'
                                : '→ للمستفسر',
                            style: TextStyle(
                              color: fg.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        if (isMe && visibility != 'all')
                          const SizedBox(height: 4),
                        if (mediaType == 'image' && mediaUrl.isNotEmpty) ...[
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
                                          child: CachedNetworkImage(
                                            imageUrl: mediaUrl,
                                            fit: BoxFit.contain,
                                            placeholder: (_, _) => const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                            errorWidget: (_, _, _) =>
                                                const Icon(
                                                  Icons.broken_image_outlined,
                                                  color: Colors.white,
                                                  size: 56,
                                                ),
                                          ),
                                        ),
                                      ),
                                      PositionedDirectional(
                                        top: 8,
                                        start: 8,
                                        child: IconButton.filled(
                                          tooltip: 'حفظ الصورة',
                                          onPressed: () =>
                                              onSaveImage(mediaUrl),
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
                                          onPressed: () => Navigator.pop(ctx),
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 260,
                                  maxHeight: 260,
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: mediaUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => SizedBox(
                                    width: 220,
                                    height: 150,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: fg,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => Container(
                                    width: 220,
                                    height: 150,
                                    color: Colors.black26,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: fg,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (body.isNotEmpty) const SizedBox(height: 8),
                        ],
                        if (mediaType == 'audio' && mediaUrl.isNotEmpty)
                          VoiceMessageBubble(
                            player: voicePlayer,
                            publicUrl: mediaUrl,
                            color: fg,
                            durationMs: durationMs,
                          ),
                        if (body.isNotEmpty)
                          GestureDetector(
                            onDoubleTap: onToggleHeart,
                            child: SelectableText(
                              body,
                              style: TextStyle(
                                color: fg,
                                height: 1.35,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (timeLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Text(
                        timeLabel,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.55),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      if (heart)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 16,
                            color: fg.withValues(alpha: 0.9),
                          ),
                        ),
                      if (showSeenByCustomer)
                        Text(
                          'تمت المشاهدة',
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.65),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return card;
  }
}

class _MediatedPartiesCard extends StatelessWidget {
  const _MediatedPartiesCard({
    required this.customerName,
    required this.customerPhone,
    required this.officeName,
    required this.officePhone,
  });

  final String? customerName;
  final String? customerPhone;
  final String? officeName;
  final String? officePhone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: _PartyPill(
                  icon: Icons.person_outline_rounded,
                  label: 'مستفسر',
                  name: customerName,
                  phone: customerPhone,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PartyPill(
                  icon: Icons.storefront_outlined,
                  label: 'معلن',
                  name: officeName,
                  phone: officePhone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartyPill extends StatelessWidget {
  const _PartyPill({
    required this.icon,
    required this.label,
    required this.name,
    required this.phone,
  });

  final IconData icon;
  final String label;
  final String? name;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayName = name?.trim() ?? '';
    final displayPhone = phone?.trim() ?? '';
    return Row(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: scheme.primary.withValues(alpha: 0.12),
          foregroundColor: scheme.primary,
          child: Icon(icon, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (displayName.isNotEmpty)
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              if (displayPhone.isNotEmpty)
                Text(
                  displayPhone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PropertySummaryCard extends StatelessWidget {
  const _PropertySummaryCard({required this.property});

  final Map<String, dynamic> property;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = property['title']?.toString() ?? '';
    final gov = property['governorate']?.toString() ?? '';
    final address = property['address_line']?.toString() ?? '';
    final publicNo = property['property_public_no']?.toString() ?? '';
    final thumb = property['thumb_url']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Card(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showAdminChatPropertyDetailSheet(context, property),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 68,
                    height: 58,
                    child: thumb.isNotEmpty
                        ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
                        : ColoredBox(
                            color: scheme.primaryContainer,
                            child: Icon(
                              Icons.article_outlined,
                              color: scheme.primary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              publicNo.isNotEmpty && publicNo != 'null'
                                  ? 'منشور #$publicNo'
                                  : 'ملخص المنشور',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          if (publicNo.isNotEmpty && publicNo != 'null')
                            IconButton(
                              tooltip: 'نسخ كود المنشور',
                              visualDensity: VisualDensity.compact,
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: '#$publicNo'),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم نسخ كود المنشور'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy_rounded, size: 18),
                            ),
                        ],
                      ),
                      Text(
                        [
                          title,
                          gov,
                          address,
                        ].where((e) => e.trim().isNotEmpty).join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReelSummaryCard extends StatelessWidget {
  const _ReelSummaryCard({required this.reel});

  final Map<String, dynamic> reel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = reel['caption']?.toString().trim() ?? '';
    final videoUrl = reel['video_public_url']?.toString().trim() ?? '';
    final propertyId = reel['property_id']?.toString().trim() ?? '';
    final reelId = reel['id']?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        color: scheme.tertiaryContainer.withValues(alpha: 0.55),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: videoUrl.isEmpty
              ? null
              : () => _showReelPreview(context, reel),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 62,
                    height: 62,
                    child: ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.video_collection_outlined,
                        color: scheme.primary,
                        size: 30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'محادثة من الريلز',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        caption.isNotEmpty ? caption : 'ريل بدون وصف',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (reelId.isNotEmpty)
                            'ريل: ${reelId.substring(0, reelId.length > 8 ? 8 : reelId.length)}',
                          if (propertyId.isNotEmpty) 'منشور مرتبط',
                          if (videoUrl.isNotEmpty) 'فيديو متوفر',
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (videoUrl.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _showReelPreview(context, reel),
                              icon: const Icon(Icons.play_circle_outline),
                              label: const Text('معاينة الريل'),
                            ),
                          if (reelId.isNotEmpty)
                            TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: reelId),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم نسخ رقم الريل'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('نسخ رقم الريل'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReelPreview(
    BuildContext context,
    Map<String, dynamic> reel,
  ) async {
    final url = reel['video_public_url']?.toString().trim() ?? '';
    if (url.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _AdminReelPreviewDialog(reel: reel),
    );
  }
}

class _AdminReelPreviewDialog extends StatefulWidget {
  const _AdminReelPreviewDialog({required this.reel});

  final Map<String, dynamic> reel;

  @override
  State<_AdminReelPreviewDialog> createState() =>
      _AdminReelPreviewDialogState();
}

class _AdminReelPreviewDialogState extends State<_AdminReelPreviewDialog> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final url = widget.reel['video_public_url']?.toString().trim() ?? '';
    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize()
          .then((_) {
            if (!mounted) return;
            _controller
              ..setLooping(true)
              ..play();
            setState(() {});
          })
          .catchError((_) {
            if (mounted) setState(() => _failed = true);
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copyReelId() async {
    final id = widget.reel['id']?.toString().trim() ?? '';
    if (id.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم نسخ رقم الريل')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = widget.reel['caption']?.toString().trim() ?? '';
    final reelId = widget.reel['id']?.toString().trim() ?? '';

    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'معاينة الريل داخل لوحة الأدمن',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: ColoredBox(
                      color: Colors.black,
                      child: _failed
                          ? const Center(
                              child: Text(
                                'تعذر تشغيل الفيديو',
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          : !_controller.value.isInitialized
                          ? const Center(child: CircularProgressIndicator())
                          : GestureDetector(
                              onTap: () {
                                setState(() {
                                  _controller.value.isPlaying
                                      ? _controller.pause()
                                      : _controller.play();
                                });
                              },
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
                                  if (!_controller.value.isPlaying)
                                    const Center(
                                      child: Icon(
                                        Icons.play_circle_fill_rounded,
                                        color: Colors.white,
                                        size: 64,
                                      ),
                                    ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: VideoProgressIndicator(
                                      _controller,
                                      allowScrubbing: true,
                                      colors: VideoProgressColors(
                                        playedColor: scheme.primary,
                                        bufferedColor: Colors.white38,
                                        backgroundColor: Colors.white12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption.isNotEmpty)
                    Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      if (reelId.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: _copyReelId,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('نسخ رقم الريل'),
                        ),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('تم'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
