import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';
import '../../auth/data/auth_controller.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  final _search = TextEditingController();
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) _load(silent: true);
      });
    });
  }

  Future<void> _load({bool silent = false}) async {
    final token = ref.read(authControllerProvider).apiToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'سجّل الدخول مرة أخرى لتحديث الجلسة.';
        _items = [];
      });
      return;
    }
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
        _error = null;
      });
    } on VewoApiException catch (e) {
      if (!mounted) return;
      if (silent) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (silent) return;
      setState(() {
        _error = 'تعذر تحميل المحادثات';
        _loading = false;
      });
    }
  }

  Widget _conversationTitle(BuildContext context, Map<String, dynamic> row) {
    final scheme = Theme.of(context).colorScheme;
    final tpn = row['thread_public_no'];
    final codeStr = (tpn != null && '$tpn'.isNotEmpty) ? '#$tpn' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppBrandStrings.plainShort,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (codeStr.isNotEmpty)
          Text(
            codeStr,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
      ],
    );
  }

  String _subtitleForRow(Map<String, dynamic> row) {
    final preview = row['last_message_preview']?.toString().trim();
    if (preview != null && preview.isNotEmpty) {
      return preview;
    }
    final ttype = row['thread_type']?.toString() ?? '';
    if (ttype == 'mediated') {
      return 'تواصل مع ${AppBrandStrings.plainShort}';
    }
    if (ttype == 'direct') {
      return 'زبون ومكتب';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const AppBarBrandTitle('المحادثات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'بحث برقم المحادثة (مثل 10052828)',
                prefixIcon: Icon(Icons.tag_rounded),
                isDense: true,
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
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
                  )
                : _items.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد محادثات بعد.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final row = _items[i];
                        final id = row['id']?.toString() ?? '';
                        final unread = (row['unread_count'] is num)
                            ? (row['unread_count'] as num).toInt()
                            : int.tryParse(
                                    row['unread_count']?.toString() ?? '0',
                                  ) ??
                                  0;
                        final thumb =
                            row['property_thumb_url']?.toString() ?? '';
                        return ListTile(
                          leading: thumb.isNotEmpty
                              ? CircleAvatar(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  backgroundImage: CachedNetworkImageProvider(
                                    thumb,
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  child: Icon(
                                    Icons.support_agent_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                          title: _conversationTitle(context, row),
                          subtitle: Text(
                            _subtitleForRow(row),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: unread > 0
                              ? Container(
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
                                )
                              : null,
                          onTap: id.isEmpty
                              ? null
                              : () {
                                  final pid = row['property_id']?.toString();
                                  if (pid != null && pid.trim().isNotEmpty) {
                                    context.push(
                                      '${AppRoutes.chatRoom}/$id?property=${Uri.encodeComponent(pid.trim())}',
                                    );
                                  } else {
                                    context.push('${AppRoutes.chatRoom}/$id');
                                  }
                                },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
