import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../engagement/admin_engagement_schedule_dialog.dart';

class AdminReelsScreen extends ConsumerStatefulWidget {
  const AdminReelsScreen({super.key});

  @override
  ConsumerState<AdminReelsScreen> createState() => _AdminReelsScreenState();
}

class _AdminReelsScreenState extends ConsumerState<AdminReelsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  final _searchNo = TextEditingController();
  bool _popularSort = false;

  static const _statuses = ['pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchNo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref
          .read(vewoApiClientProvider)
          .getJson(
            'admin/reels',
            query: {
              'status': _statuses[_tabs.index],
              if (_searchNo.text.trim().isNotEmpty)
                'q': _searchNo.text.trim().replaceFirst(RegExp(r'^#+'), ''),
              if (_popularSort && _tabs.index == 1) 'sort': 'popular',
            },
          );
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
        _items = list;
        _loading = false;
      });
    } on VewoApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الريلز';
        _loading = false;
      });
    }
  }

  Future<void> _action(String id, String action) async {
    try {
      await ref.read(vewoApiClientProvider).postJson('admin/reels', {
        'id': id,
        'action': action,
      });
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _scheduleEngagement(int publicNo) async {
    await showAdminEngagementScheduleDialog(
      context: context,
      ref: ref,
      targetKind: 'reel',
      publicNo: publicNo,
      title: 'جدولة ريل #$publicNo',
      likesForProperty: false,
    );
  }

  Future<void> _previewVideo(Map<String, dynamic> r) async {
    final url = r['video_public_url']?.toString() ?? '';
    if (url.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AdminReelPreviewDialog(videoUrl: url, row: r),
    );
  }

  Future<void> _previewThenApprove(Map<String, dynamic> r) async {
    final id = r['id']?.toString() ?? '';
    final url = r['video_public_url']?.toString() ?? '';
    if (id.isEmpty || url.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          _AdminReelPreviewDialog(videoUrl: url, row: r, reviewMode: true),
    );
    if (ok == true) {
      await _action(id, 'approve');
    }
  }

  Future<void> _delete(String id) async {
    if (id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الريل'),
        content: const Text('هل تريد حذف هذا الريل نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(vewoApiClientProvider)
          .deleteJson('admin/reels', query: {'id': id});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف الريل')));
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = switch (_tabs.index) {
      0 => 'لا توجد ريلز بانتظار الموافقة.',
      1 => 'لا توجد ريلز منشورة.',
      _ => 'لا توجد ريلز مرفوضة.',
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchNo,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'بحث برقم الريل (مثل #30000001)',
              prefixIcon: Icon(Icons.tag_rounded),
              isDense: true,
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        if (_tabs.index == 1)
          SwitchListTile(
            title: const Text('ترتيب حسب الشعبية (مشاهدات + لايكات)'),
            value: _popularSort,
            onChanged: (v) {
              setState(() => _popularSort = v);
              _load();
            },
          ),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: TabBar(
            controller: _tabs,
            onTap: (_) => _load(),
            tabs: const [
              Tab(text: 'مراجعة'),
              Tab(text: 'منشورة'),
              Tab(text: 'مرفوضة'),
            ],
          ),
        ),
        if (_error != null)
          ListTile(
            leading: const Icon(Icons.warning_amber_rounded),
            title: Text(_error!),
            trailing: TextButton(onPressed: _load, child: const Text('إعادة')),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 80),
                      const Icon(Icons.video_collection_outlined, size: 52),
                      const SizedBox(height: 12),
                      Text(empty, textAlign: TextAlign.center),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final r = _items[index];
                      final id = r['id']?.toString() ?? '';
                      final role = r['role']?.toString() ?? '';
                      final office = r['office_name']?.toString() ?? '';
                      final name = role == 'office' && office.isNotEmpty
                          ? office
                          : (r['full_name']?.toString() ?? '—');
                      final caption = r['caption']?.toString() ?? '';
                      final reelPub = r['reel_public_no'];
                      final reelPubStr =
                          reelPub != null && '$reelPub'.isNotEmpty
                          ? '#$reelPub'
                          : '';
                      final vc = r['view_count'];
                      final rl = r['real_likes_count'];
                      final syn = r['synthetic_likes'];
                      final pub = reelPub is num
                          ? reelPub.toInt()
                          : int.tryParse('$reelPub') ?? 0;
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _previewVideo(r),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                role == 'office'
                                    ? Icons.storefront_outlined
                                    : Icons.person_outline_rounded,
                              ),
                            ),
                            title: Text(
                              reelPubStr.isNotEmpty
                                  ? '$name · $reelPubStr'
                                  : name,
                            ),
                            subtitle: Text(
                              [
                                if (caption.isNotEmpty) caption,
                                if (vc != null || rl != null || syn != null)
                                  'مشاهدات: ${vc ?? 0} • لايكات: ${rl ?? 0} + تركيبي ${syn ?? 0}',
                              ].join('\n'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Wrap(
                              spacing: 6,
                              children: [
                                if (pub > 0)
                                  IconButton(
                                    tooltip: 'جدولة مشاهدات/لايكات',
                                    onPressed: () => _scheduleEngagement(pub),
                                    icon: const Icon(Icons.trending_up_rounded),
                                  ),
                                if (_tabs.index == 0) ...[
                                  IconButton.filledTonal(
                                    tooltip: 'نشر',
                                    onPressed: id.isEmpty
                                        ? null
                                        : () => _previewThenApprove(r),
                                    icon: const Icon(Icons.check_rounded),
                                  ),
                                  IconButton.outlined(
                                    tooltip: 'رفض',
                                    onPressed: id.isEmpty
                                        ? null
                                        : () => _action(id, 'reject'),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                                IconButton(
                                  tooltip: 'حذف',
                                  onPressed: id.isEmpty
                                      ? null
                                      : () => _delete(id),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _AdminReelPreviewDialog extends StatefulWidget {
  const _AdminReelPreviewDialog({
    required this.videoUrl,
    required this.row,
    this.reviewMode = false,
  });

  final String videoUrl;
  final Map<String, dynamic> row;
  final bool reviewMode;

  @override
  State<_AdminReelPreviewDialog> createState() =>
      _AdminReelPreviewDialogState();
}

class _AdminReelPreviewDialogState extends State<_AdminReelPreviewDialog> {
  late final VideoPlayerController _c;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          _c.setLooping(true);
          _c.play();
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caption = widget.row['caption']?.toString() ?? '';
    final pub = widget.row['reel_public_no'];
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_c.value.isInitialized)
              AspectRatio(
                aspectRatio: _c.value.aspectRatio > 0
                    ? _c.value.aspectRatio
                    : 9 / 16,
                child: VideoPlayer(_c),
              )
            else
              const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (pub != null)
                    Text(
                      'ريل #$pub',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  if (caption.isNotEmpty)
                    Text(caption, maxLines: 4, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  if (widget.reviewMode)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('رجوع'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(context, true),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('موافقة ونشر'),
                          ),
                        ),
                      ],
                    )
                  else
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إغلاق'),
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
