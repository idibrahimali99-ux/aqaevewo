import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

/// إدارة أخبار العقارات (عنوان، صورة، وصف تفصيلي) — تظهر في تطبيق View تحت الإعلانات.
class AdminPropertyNewsScreen extends ConsumerStatefulWidget {
  const AdminPropertyNewsScreen({super.key});

  @override
  ConsumerState<AdminPropertyNewsScreen> createState() =>
      _AdminPropertyNewsScreenState();
}

class _AdminPropertyNewsScreenState
    extends ConsumerState<AdminPropertyNewsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

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
      final data = await api.getJson('admin_property_news');
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

  Future<void> _delete(String id) async {
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.deleteJson('admin_property_news', query: {'id': id});
      await _load();
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _showAddDialog([Map<String, dynamic>? item]) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AddNewsDialog(item: item),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _load,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.newspaper_rounded),
        label: const Text('خبر جديد'),
      ),
      body: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
                Icon(
                  Icons.article_outlined,
                  size: 56,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'لا توجد أخبار بعد.\nأضف عنواناً وصورة ووصفاً تفصيلياً — يظهر الخبر في التطبيق كمنشور.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final it = _items[i];
                  final id = it['id']?.toString() ?? '';
                  final body = it['body']?.toString() ?? '';
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      isThreeLine: true,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          it['image_url']?.toString() ?? '',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 64,
                                height: 64,
                                color: scheme.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                        ),
                      ),
                      title: Text(
                        it['title']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        body.length > 120 ? '${body.substring(0, 120)}…' : body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'تعديل',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: id.isEmpty
                                ? null
                                : () => _showAddDialog(it),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: id.isEmpty ? null : () => _delete(id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _AddNewsDialog extends ConsumerStatefulWidget {
  const _AddNewsDialog({this.item});

  final Map<String, dynamic>? item;

  @override
  ConsumerState<_AddNewsDialog> createState() => _AddNewsDialogState();
}

class _AddNewsDialogState extends ConsumerState<_AddNewsDialog> {
  late final TextEditingController _title;
  late final TextEditingController _imageUrl;
  late final TextEditingController _body;
  late final TextEditingController _sort;
  final _picker = ImagePicker();
  bool _saving = false;
  bool _uploading = false;

  bool get _editing => (widget.item?['id']?.toString() ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?['title']?.toString() ?? '');
    _imageUrl = TextEditingController(
      text: item?['image_url']?.toString() ?? '',
    );
    _body = TextEditingController(text: item?['body']?.toString() ?? '');
    _sort = TextEditingController(text: item?['sort_order']?.toString() ?? '0');
  }

  @override
  void dispose() {
    _title.dispose();
    _imageUrl.dispose();
    _body.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    setState(() => _uploading = true);
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final api = ref.read(vewoApiClientProvider);
      final data = await api.postMultipartFile(
        'admin/upload',
        'file',
        file.path,
      );
      final url = data['public_url']?.toString();
      if (url == null || url.isEmpty) {
        throw VewoApiException('لم يُرجع السيرفر رابط الملف');
      }
      if (!mounted) return;
      setState(() => _imageUrl.text = url);
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر اختيار الصورة أو رفعها')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _imageUrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('العنوان ورابط الصورة مطلوبان')),
      );
      return;
    }
    if (_body.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الوصف التفصيلي مطلوب (20 حرفاً على الأقل)'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin_property_news', {
        if (_editing) 'id': widget.item?['id']?.toString(),
        if (_editing) 'action': 'update',
        'title': _title.text.trim(),
        'image_url': _imageUrl.text.trim(),
        'body': _body.text.trim(),
        'sort_order': int.tryParse(_sort.text.trim()) ?? 0,
      });
      if (!mounted) return;
      Navigator.pop(context);
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'تعديل الخبر العقاري' : 'خبر عقاري جديد'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'عنوان الخبر'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _imageUrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'رابط صورة الغلاف',
                        hintText: 'ارفع صورة أو الصق الرابط',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'صورة من المعرض',
                    onPressed: _uploading || _saving ? null : _pickAndUpload,
                    icon: _uploading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library_outlined),
                  ),
                ],
              ),
              if (_imageUrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: InkWell(
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
                                      _imageUrl.text.trim(),
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white,
                                        size: 56,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.directional(
                                  textDirection: Directionality.of(ctx),
                                  top: 8,
                                  end: 8,
                                  child: IconButton.filled(
                                    onPressed: () => Navigator.pop(ctx),
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      child: Image.network(
                        _imageUrl.text.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'اضغط على الصورة للمعاينة بالحجم الكامل',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _body,
                minLines: 5,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'الوصف التفصيلي (يظهر كمنشور كامل في التطبيق)',
                  alignLabelWithHint: true,
                ),
              ),
              TextField(
                controller: _sort,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ترتيب العرض'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_editing ? 'حفظ التعديل' : 'حفظ'),
        ),
      ],
    );
  }
}
