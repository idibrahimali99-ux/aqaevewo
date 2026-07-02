import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import 'admin_chat_room_screen.dart';

class AdminChatsScreen extends ConsumerStatefulWidget {
  const AdminChatsScreen({super.key});

  @override
  ConsumerState<AdminChatsScreen> createState() => _AdminChatsScreenState();
}

class _AdminChatsScreenState extends ConsumerState<AdminChatsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(vewoApiClientProvider);
      final q = _search.text.trim();
      final data = await api.getJson(
        'chat/threads',
        query: q.isEmpty ? null : {'q': q},
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
        _error = 'تعذر التحميل';
        _loading = false;
      });
    }
  }

  String _subtitle(Map<String, dynamic> row) {
    final parts = <String>[];
    final lm = row['last_message_at']?.toString().trim();
    if (lm != null && lm.isNotEmpty) {
      final d = DateTime.tryParse(lm);
      if (d != null) {
        String two(int n) => n.toString().padLeft(2, '0');
        parts.add(
          '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}',
        );
      }
    }
    final ttype = row['thread_type']?.toString() ?? '';
    if (ttype == 'direct') {
      parts.add('مستفسر ↔ معلن');
    } else if (ttype == 'mediated') {
      final c =
          row['customer_display_name']?.toString() ??
          row['customer_name']?.toString() ??
          '';
      final o =
          row['office_display_name']?.toString() ??
          row['office_name']?.toString() ??
          row['office_full_name']?.toString() ??
          '';
      parts.add('عبر الإدارة');
      if (c.isNotEmpty) parts.add('مستفسر: $c');
      if (o.isNotEmpty) parts.add('معلن: $o');
    }
    final propertyNo = row['property_public_no']?.toString().trim() ?? '';
    final propertyTitle = row['property_title']?.toString().trim() ?? '';
    final owner = row['office_display_name']?.toString().trim() ?? '';
    if (propertyNo.isNotEmpty || propertyTitle.isNotEmpty) {
      parts.add(
        [
          if (propertyNo.isNotEmpty) 'منشور #$propertyNo',
          if (propertyTitle.isNotEmpty) propertyTitle,
        ].join(' — '),
      );
    }
    final reelId = row['reel_id']?.toString().trim() ?? '';
    final reelCaption = row['reel_caption']?.toString().trim() ?? '';
    if (reelId.isNotEmpty || reelCaption.isNotEmpty) {
      parts.add(['ريلز', if (reelCaption.isNotEmpty) reelCaption].join(' — '));
    }
    if (owner.isNotEmpty && !parts.contains('معلن: $owner')) {
      parts.add('صاحب المنشور: $owner');
    }
    final prev = row['last_message_preview']?.toString().trim();
    if (prev != null && prev.isNotEmpty) {
      parts.add(prev);
    }
    return parts.where((e) => e.isNotEmpty).join(' · ');
  }

  String _title(Map<String, dynamic> row) {
    final tpn = row['thread_public_no'];
    final first =
        row['first_sender_name']?.toString().trim() ??
        row['customer_display_name']?.toString().trim() ??
        row['customer_name']?.toString().trim() ??
        '';
    final numPart = tpn != null && '$tpn'.isNotEmpty ? '#$tpn' : 'محادثة';
    if (first.isEmpty) return numPart;
    return '$numPart · $first';
  }

  int _unread(Map<String, dynamic> row) {
    final raw = row['unread_count'];
    return raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '0') ?? 0;
  }

  List<Map<String, dynamic>> _visibleItems() {
    return _items.where((row) {
      final unread = _unread(row);
      if (_filter == 'unread') return unread > 0;
      if (_filter == 'read') return unread == 0;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final rows = _visibleItems();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'بحث برقم المحادثة',
              prefixIcon: Icon(Icons.tag_rounded),
              isDense: true,
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('الكل')),
              ButtonSegment(value: 'unread', label: Text('لم تُقرأ')),
              ButtonSegment(value: 'read', label: Text('تمت قراءتها')),
            ],
            selected: {_filter},
            onSelectionChanged: (v) => setState(() => _filter = v.first),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد محادثات بعد.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: rows.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      final id = row['id']?.toString() ?? '';
                      final unread = _unread(row);
                      final thumb = row['property_thumb_url']?.toString() ?? '';
                      return Card(
                        color: unread > 0
                            ? Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: 0.22)
                            : null,
                        child: ListTile(
                          leading: thumb.isNotEmpty
                              ? CircleAvatar(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  backgroundImage: CachedNetworkImageProvider(
                                    thumb,
                                  ),
                                )
                              : const CircleAvatar(
                                  child: Icon(Icons.forum_outlined),
                                ),
                          title: Text(_title(row)),
                          subtitle: Text(_subtitle(row), maxLines: 2),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (unread > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    unread > 99 ? '99+' : '$unread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 10),
                              const Icon(Icons.chevron_left),
                            ],
                          ),
                          onTap: id.isEmpty
                              ? null
                              : () {
                                  Navigator.of(context)
                                      .push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              AdminChatRoomScreen(threadId: id),
                                        ),
                                      )
                                      .then((_) => _load());
                                },
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
