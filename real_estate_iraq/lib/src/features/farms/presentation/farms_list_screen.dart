import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_responsive.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../../routing/app_routes.dart';

class FarmsListScreen extends ConsumerStatefulWidget {
  const FarmsListScreen({super.key});

  @override
  ConsumerState<FarmsListScreen> createState() => _FarmsListScreenState();
}

class _FarmsListScreenState extends ConsumerState<FarmsListScreen> {
  final _query = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _query.text.trim();
      final data = await ref.read(vewoApiClientProvider).getJson(
        'farms/list',
        query: {if (q.isNotEmpty) 'q': q},
      );
      final raw = data['items'];
      final items = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) items.add(Map<String, dynamic>.from(e));
        }
      }
      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      for (final item in items) {
        final key = item['id']?.toString() ?? '';
        if (key.isEmpty || !seen.add(key)) continue;
        unique.add(item);
      }
      if (!mounted) return;
      setState(() {
        _items = unique;
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
        _error = 'تعذر تحميل المزارع';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مزارع للحجز')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث باسم المزرعة أو المنطقة',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : _items.isEmpty
                ? const Center(child: Text('لا توجد مزارع منشورة حالياً'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: AppResponsive.pagePadding(context, top: 4, accountForShellNav: true),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final farm = _items[index];
                        final id = farm['id']?.toString() ?? '';
                        final name = farm['name']?.toString() ?? 'مزرعة';
                        final code = farm['public_code']?.toString() ?? '';
                        final place = [
                          farm['governorate'],
                          farm['city'],
                          farm['district'],
                        ].whereType<String>().where((e) => e.trim().isNotEmpty).join(' · ');
                        final price = farm['price_from'];
                        final images = _farmImages(farm);
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: id.isEmpty
                                ? null
                                : () => context.push('${AppRoutes.farmProfile}/$id'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (images.isNotEmpty)
                                  SizedBox(
                                    height: 180,
                                    child: Stack(
                                      children: [
                                        PageView.builder(
                                          itemCount: images.length,
                                          itemBuilder: (context, imageIndex) => CachedNetworkImage(
                                            imageUrl: images[imageIndex],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          ),
                                        ),
                                        if (images.length > 1)
                                          const Positioned(
                                            bottom: 8,
                                            left: 8,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(color: Color(0x99000000), borderRadius: BorderRadius.all(Radius.circular(8))),
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                child: Text('اسحب الصور', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                  if (code.isNotEmpty)
                                    Text(
                                      'رقم المزرعة $code',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  if (place.isNotEmpty) Text(place),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Chip(
                                      avatar: const Icon(Icons.event_available, size: 18),
                                      label: Text('احجز · يبدأ من ${_money(price)} د.ع'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                              ],
                            ),
                          ),
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

List<String> _farmImages(Map<String, dynamic> farm) {
  final urls = <String>[];
  final raw = farm['images'];
  if (raw is List) {
    for (final e in raw) {
      if (e is Map) {
        final url = e['url']?.toString().trim() ?? '';
        if (url.isNotEmpty) urls.add(url);
      } else {
        final url = e.toString().trim();
        if (url.startsWith('http')) urls.add(url);
      }
    }
  }
  final cover = farm['cover_url']?.toString().trim() ?? '';
  if (cover.isNotEmpty && !urls.contains(cover)) urls.insert(0, cover);
  return urls;
}

String _money(Object? raw) {
  final n = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
