import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../users/presentation/admin_user_profile_screen.dart';

/// بطاقة منشور كاملة من بيانات الـ API (محادثات الأدمن).
Future<void> showAdminChatPropertyDetailSheet(
  BuildContext context,
  Map<String, dynamic> property,
) async {
  final scheme = Theme.of(context).colorScheme;
  final title = property['title']?.toString() ?? '—';
  final detailsRaw = property['details_json']?.toString();
  final desc = property['description']?.toString() ?? '';
  final gov = property['governorate']?.toString() ?? '';
  final addr = property['address_line']?.toString() ?? '';
  final ownerId = property['owner_user_id']?.toString() ?? '';
  final publicNo = property['property_public_no'];
  final pubLabel =
      publicNo != null && '$publicNo'.isNotEmpty && '$publicNo' != 'null'
      ? '#$publicNo'
      : '';

  final imgs = _imageUrls(property);
  final (lat, lng) = _latLngFromDetails(detailsRaw);
  final parsed = _tryParseJson(detailsRaw);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.45,
        maxChildSize: 0.98,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (pubLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ActionChip(
                    avatar: const Icon(Icons.copy_rounded, size: 18),
                    label: Text('رقم المنشور $pubLabel'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: pubLabel));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ كود المنشور')),
                        );
                      }
                    },
                    labelStyle: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (ownerId.isNotEmpty)
                Material(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AdminUserProfileScreen(userId: ownerId),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'عرض حساب الناشر',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Icon(Icons.chevron_left, color: scheme.primary),
                        ],
                      ),
                    ),
                  ),
                ),
              if (ownerId.isNotEmpty) const SizedBox(height: 12),
              if (imgs.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    itemCount: imgs.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: imgs[i],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (_, __) =>
                              ColoredBox(color: scheme.surfaceContainerHighest),
                        ),
                      ),
                    ),
                  ),
                ),
              if (imgs.isNotEmpty) const SizedBox(height: 14),
              if (lat != null && lng != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: _staticMapUrl(lat, lng),
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          ColoredBox(color: scheme.surfaceContainerHighest),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final uri = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                        );
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('خرائط'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              if (gov.isNotEmpty || addr.isNotEmpty)
                Text(
                  [gov, addr].where((e) => e.trim().isNotEmpty).join(' • '),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 10),
              _priceArea(context, property['price_iqd']),
              _areaRow(context, property['area_sqm']),
              if (desc.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'الوصف',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                SelectableText(desc, style: const TextStyle(height: 1.35)),
              ],
              if (parsed != null && parsed.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'تفاصيل إضافية',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ..._humanDetailRows(context, parsed),
              ],
            ],
          );
        },
      );
    },
  );
}

List<String> _imageUrls(Map<String, dynamic> property) {
  final raw = property['image_urls'];
  if (raw is List) {
    final out = <String>[];
    for (final e in raw) {
      final s = e?.toString().trim() ?? '';
      if (s.isNotEmpty) out.add(s);
    }
    if (out.isNotEmpty) return out;
  }
  final t = property['thumb_url']?.toString().trim() ?? '';
  return t.isNotEmpty ? [t] : <String>[];
}

String? _sanitizeDetailsJson(String? s) {
  if (s == null) return null;
  var t = s.trim();
  if (t.isEmpty || t == 'null') return null;
  final i = t.indexOf('{');
  if (i > 0) {
    t = t.substring(i);
  }
  return t;
}

Map<String, dynamic>? _tryParseJson(String? s) {
  final raw = _sanitizeDetailsJson(s);
  if (raw == null) return null;
  try {
    final o = jsonDecode(raw);
    if (o is Map) return Map<String, dynamic>.from(o);
  } catch (_) {}
  return null;
}

(double?, double?) _latLngFromDetails(String? details) {
  final m = _tryParseJson(details);
  if (m == null) return (null, null);
  double? toD(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  final loc = m['location'];
  if (loc is Map) {
    final lm = Map<String, dynamic>.from(loc);
    final la = toD(lm['lat'] ?? lm['latitude']);
    final ln = toD(lm['lng'] ?? lm['longitude'] ?? lm['lon']);
    if (la != null && ln != null) return (la, ln);
  }

  final la = toD(m['lat'] ?? m['latitude']);
  final ln = toD(m['lng'] ?? m['longitude'] ?? m['lon']);
  return (la, ln);
}

String _staticMapUrl(double lat, double lng) {
  return 'https://staticmap.openstreetmap.de/staticmap.php?center=$lat,$lng&zoom=15&size=640x280&markers=$lat,$lng,red-pushpin';
}

Widget _priceArea(BuildContext context, dynamic value) {
  if (value == null || '$value'.trim().isEmpty || '$value' == 'null') {
    return const SizedBox.shrink();
  }
  final n = value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0;
  if (n <= 0) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            'السعر',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            '$n د.ع',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

Widget _areaRow(BuildContext context, dynamic value) {
  if (value == null || '$value'.trim().isEmpty || '$value' == 'null') {
    return const SizedBox.shrink();
  }
  final n = value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0;
  if (n <= 0) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            'المساحة',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Text('$n م²')),
      ],
    ),
  );
}

List<Widget> _humanDetailRows(BuildContext context, Map<String, dynamic> map) {
  const labels = <String, String>{
    'parcel_listing': 'أرض مقسمة',
    'negotiable': 'قابل للتفاوض',
    'district_name': 'المنطقة / القضاء',
    'parcel_name': 'المقاطعة',
    'compound_name': 'المجمع',
    'notes': 'ملاحظات',
    'floor': 'الطابق',
    'rooms': 'الغرف',
    'bathrooms': 'الحمامات',
    'bedrooms': 'غرف النوم',
    'living_rooms': 'الصالات',
    'kitchens': 'المطابخ',
    'parking': 'موقف سيارات',
    'furnished': 'مفروش',
  };

  String fmt(dynamic v) {
    if (v == null) return '';
    if (v is bool) return v ? 'نعم' : 'لا';
    if (v is Map || v is List) return '';
    return v.toString().trim();
  }

  final rows = <Widget>[];
  final scheme = Theme.of(context).colorScheme;
  map.forEach((key, value) {
    if (!labels.containsKey(key)) return;
    final label = labels[key]!;
    final text = fmt(value);
    if (text.isEmpty) return;
    rows.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                text,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  });
  return rows;
}
