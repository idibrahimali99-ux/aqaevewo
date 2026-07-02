import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';

String _slotLabelAr(String? s) {
  switch ((s ?? '').trim().toLowerCase()) {
    case 'search':
      return 'شاشة البحث';
    case 'home':
    case '':
    case 'main':
      return 'الرئيسية';
    default:
      return s ?? 'الرئيسية';
  }
}

String _displayModeAr(String? dm) {
  switch (dm ?? '') {
    case 'popup':
      return 'منبثق (عدّ تنازلي)';
    case 'slider':
      return 'سلايدر';
    default:
      return 'منبثق + سلايدر';
  }
}

String _promotionListSubtitle(Map<String, dynamic> it) {
  final slot = _slotLabelAr(it['slot']?.toString());
  final mode = _displayModeAr(it['display_mode']?.toString());
  final endsRaw = it['campaign_ends_at']?.toString();
  var tail = '';
  if (endsRaw != null && endsRaw.isNotEmpty) {
    final d = DateTime.tryParse(endsRaw);
    if (d != null) {
      final diff = d.difference(DateTime.now());
      if (diff.isNegative) {
        tail = ' • منتهٍ';
      } else if (diff.inDays >= 1) {
        tail = ' • متبقي ${diff.inDays} يوم';
      } else if (diff.inHours >= 1) {
        tail = ' • متبقي ${diff.inHours} ساعة';
      } else {
        tail = ' • متبقي ${diff.inMinutes} دقيقة';
      }
    }
  }
  final link = (it['link_target']?.toString() ?? '').trim();
  final linkNote = link.isEmpty ? '' : ' • رابط عند الضغط';
  return '$slot • $mode$tail$linkNote';
}

/// إدارة سلايدر «إعلانات مميزة» في تطبيق العقار الرئيسي.
class AdminHomePromotionsScreen extends ConsumerStatefulWidget {
  const AdminHomePromotionsScreen({super.key});

  @override
  ConsumerState<AdminHomePromotionsScreen> createState() =>
      _AdminHomePromotionsScreenState();
}

class _AdminHomePromotionsScreenState
    extends ConsumerState<AdminHomePromotionsScreen> {
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
      final data = await api.getJson('admin/promotions');
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
      await api.deleteJson('admin/promotions', query: {'id': id});
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
      builder: (ctx) => _AddPromotionDialog(item: item),
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
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('إعلان جديد'),
      ),
      body: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                Icon(
                  Icons.campaign_outlined,
                  size: 56,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'لا توجد إعلانات بعد.\nاضغط «إعلان جديد» لإضافة أول بانر يظهر في التطبيق.',
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
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
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
                        _promotionListSubtitle(it),
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

class _AddPromotionDialog extends ConsumerStatefulWidget {
  const _AddPromotionDialog({this.item});

  final Map<String, dynamic>? item;

  @override
  ConsumerState<_AddPromotionDialog> createState() =>
      _AddPromotionDialogState();
}

class _AddPromotionDialogState extends ConsumerState<_AddPromotionDialog> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _imageUrl;
  late final TextEditingController _linkUrl;
  late final TextEditingController _popupSec;
  late final TextEditingController _campaignDays;
  late final TextEditingController _sort;
  final _picker = ImagePicker();
  String _displayMode = 'both';
  String _slot = 'home';
  String _linkType = 'none';
  bool _saving = false;
  bool _uploading = false;

  bool get _editing => (widget.item?['id']?.toString() ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?['title']?.toString() ?? '');
    _subtitle = TextEditingController(
      text: item?['subtitle']?.toString() ?? '',
    );
    _imageUrl = TextEditingController(
      text: item?['image_url']?.toString() ?? '',
    );
    _linkUrl = TextEditingController(
      text: item?['link_target']?.toString() ?? '',
    );
    _popupSec = TextEditingController(
      text: item?['popup_duration_sec']?.toString() ?? '20',
    );
    _campaignDays = TextEditingController(text: '0');
    _sort = TextEditingController(text: item?['sort_order']?.toString() ?? '0');
    _displayMode = item?['display_mode']?.toString() ?? 'both';
    _slot = item?['slot']?.toString() ?? 'home';
    _linkType = item?['link_type']?.toString() ?? 'none';
    if (!['both', 'slider', 'popup'].contains(_displayMode)) {
      _displayMode = 'both';
    }
    if (!['home', 'search'].contains(_slot)) {
      _slot = 'home';
    }
    if (![
      'none',
      'url',
      'route',
      'property',
      'property_no',
    ].contains(_linkType)) {
      _linkType = 'none';
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _imageUrl.dispose();
    _linkUrl.dispose();
    _popupSec.dispose();
    _campaignDays.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload({required bool video}) async {
    setState(() => _uploading = true);
    try {
      final XFile? file = video
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.gallery);
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
        const SnackBar(content: Text('تعذر اختيار الملف أو رفعه')),
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
    setState(() => _saving = true);
    try {
      final api = ref.read(vewoApiClientProvider);
      await api.postJson('admin/promotions', {
        if (_editing) 'id': widget.item?['id']?.toString(),
        if (_editing) 'action': 'update',
        'title': _title.text.trim(),
        'subtitle': _subtitle.text.trim(),
        'image_url': _imageUrl.text.trim(),
        'link_type': _linkUrl.text.trim().isEmpty ? 'none' : _linkType,
        'link_target': _linkUrl.text.trim(),
        'display_mode': _displayMode,
        'popup_duration_sec': int.tryParse(_popupSec.text.trim()) ?? 20,
        'campaign_days': int.tryParse(_campaignDays.text.trim()) ?? 0,
        'sort_order': int.tryParse(_sort.text.trim()) ?? 0,
        'slot': _slot,
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
      title: Text(_editing ? 'تعديل الإعلان' : 'إعلان جديد للرئيسية'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            TextField(
              controller: _subtitle,
              decoration: const InputDecoration(
                labelText: 'وصف قصير (اختياري)',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _imageUrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'رابط الصورة أو الفيديو',
                      hintText: 'ارفع ملفاً أو الصق رابطاً',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'صورة من المعرض',
                  onPressed: _uploading || _saving
                      ? null
                      : () => _pickAndUpload(video: false),
                  icon: _uploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                ),
                IconButton.filledTonal(
                  tooltip: 'فيديو من المعرض',
                  onPressed: _uploading || _saving
                      ? null
                      : () => _pickAndUpload(video: true),
                  icon: const Icon(Icons.video_library_outlined),
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
            ],
            DropdownButtonFormField<String>(
              initialValue: _displayMode,
              decoration: const InputDecoration(labelText: 'وضع العرض'),
              items: const [
                DropdownMenuItem(value: 'both', child: Text('منبثق + سلايدر')),
                DropdownMenuItem(value: 'slider', child: Text('سلايدر فقط')),
                DropdownMenuItem(
                  value: 'popup',
                  child: Text('منبثق فقط (مع عدّاد ثوانٍ للإغلاق)'),
                ),
              ],
              onChanged: (v) => setState(() => _displayMode = v ?? 'both'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _slot,
              decoration: const InputDecoration(
                labelText: 'مكان الظهور في التطبيق',
                helperText:
                    'الرئيسية: سلايدر الإعلانات. البحث: يمكن ربطه لاحقاً بشاشة البحث.',
              ),
              items: const [
                DropdownMenuItem(value: 'home', child: Text('الصفحة الرئيسية')),
                DropdownMenuItem(
                  value: 'search',
                  child: Text('شاشة البحث (slot=search)'),
                ),
              ],
              onChanged: (v) => setState(() => _slot = v ?? 'home'),
            ),
            TextField(
              controller: _popupSec,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ثواني إغلاق النافذة المنبثقة',
                helperText: 'من 5 إلى 120 ثانية',
              ),
            ),
            TextField(
              controller: _campaignDays,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'مدة الحملة (أيام)',
                helperText: '0 = بدون نهاية؛ يُخفى الإعلان بعد انتهاء المدة',
              ),
            ),
            TextField(
              controller: _linkUrl,
              decoration: const InputDecoration(
                labelText: 'هدف الضغط (اختياري)',
                hintText: 'رابط، مسار، أو رقم منشور مثل #20000001',
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _linkType,
              decoration: const InputDecoration(
                labelText: 'نوع هدف الضغط',
                helperText: 'اختر رقم منشور لفتح تفاصيل عقار من الإعلان.',
              ),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('بدون رابط')),
                DropdownMenuItem(value: 'url', child: Text('رابط خارجي')),
                DropdownMenuItem(
                  value: 'route',
                  child: Text('مسار داخل التطبيق'),
                ),
                DropdownMenuItem(
                  value: 'property',
                  child: Text('معرّف عقار UUID'),
                ),
                DropdownMenuItem(
                  value: 'property_no',
                  child: Text('رقم منشور عام #'),
                ),
              ],
              onChanged: (v) => setState(() => _linkType = v ?? 'none'),
            ),
            TextField(
              controller: _sort,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ترتيب العرض'),
            ),
          ],
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
