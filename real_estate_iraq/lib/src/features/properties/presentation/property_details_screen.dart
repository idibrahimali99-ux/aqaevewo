import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vewo_shared/vewo_shared.dart' show IQDFormatter;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/app_bootstrap_provider.dart';
import '../../../core/api/vewo_api_client.dart';
import '../../../core/location/location_providers.dart';
import '../../../core/widgets/property_image_gallery.dart';
import '../../../core/widgets/property_video_player.dart';
import '../../../core/widgets/property_map_embed.dart';
import 'property_contact_guard.dart';
import '../../../routing/app_routes.dart';
import '../../../routing/auth_nav.dart';
import '../../auth/data/auth_controller.dart';
import '../../favorites/data/favorites_controller.dart';
import '../data/properties_providers.dart';
import '../domain/property.dart';
import '../domain/property_category.dart';
import '../domain/property_segment.dart';

class PropertyDetailsScreen extends ConsumerWidget {
  const PropertyDetailsScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProp = ref.watch(propertyDetailProvider(propertyId));

    return asyncProp.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const Scaffold(body: Center(child: Text('تعذر تحميل العقار'))),
      data: (property) {
        if (property == null) {
          return const Scaffold(body: Center(child: Text('العقار غير موجود')));
        }
        return _PropertyDetailsBody(property: property);
      },
    );
  }
}

/// واتساب الدعم/التواصل (بدون الصفر الأولى مع رمز العراق).
const _kWhatsAppLaunchDigits = '9647871456461';

const _kWhatsAppMiniSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <path fill="#25D366" d="M16 3C8.82 3 3 8.82 3 16c0 2.43.66 4.7 1.82 6.65L3 29l6.52-1.72A12.9 12.9 0 0 0 16 29c7.18 0 13-5.82 13-13S23.18 3 16 3z"/>
  <path fill="#fff" d="M12.36 9.98c-.3-.67-.61-.68-.9-.69h-.77c-.2 0-.53.08-.8.38-.28.3-1.05 1.02-1.05 2.49s1.08 2.89 1.23 3.09c.15.2 2.08 3.33 5.12 4.54 2.52 1 3.03.8 3.57.75.55-.05 1.78-.72 2.03-1.42.25-.7.25-1.3.18-1.42-.08-.12-.28-.2-.58-.35-.3-.15-1.78-.88-2.05-.98-.27-.1-.47-.15-.67.15-.2.3-.77.98-.95 1.18-.17.2-.35.23-.65.08-.3-.15-1.27-.47-2.42-1.5-.89-.79-1.49-1.77-1.66-2.07-.18-.3-.02-.46.13-.61.13-.13.3-.35.45-.52.15-.17.2-.3.3-.5.1-.2.05-.38-.03-.53-.08-.15-.72-1.78-.99-2.45z"/>
</svg>
''';

Future<bool> openWhatsAppSupport() async {
  final phone = _kWhatsAppLaunchDigits;
  final candidates = [
    Uri.parse('https://api.whatsapp.com/send?phone=$phone'),
    Uri.parse('https://wa.me/$phone'),
    Uri.parse('whatsapp://send?phone=$phone'),
  ];
  for (final uri in candidates) {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (_) {}
  }
  return false;
}

class _PropertyDetailsBody extends ConsumerStatefulWidget {
  const _PropertyDetailsBody({required this.property});

  final Property property;

  @override
  ConsumerState<_PropertyDetailsBody> createState() =>
      _PropertyDetailsBodyState();
}

class _PropertyDetailsBodyState extends ConsumerState<_PropertyDetailsBody> {
  bool _busySold = false;

  bool get _negotiableFlag {
    final d = widget.property.detailsJson;
    if (d == null) return false;
    final v = d['negotiable'];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }
    return false;
  }

  void _copyPublicNo(int no) {
    final label = '#$no';
    Clipboard.setData(ClipboardData(text: label));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تم نسخ $label')));
  }

  Future<void> _markSold() async {
    setState(() => _busySold = true);
    try {
      await ref.read(vewoApiClientProvider).postJson('properties/mark-sold', {
        'property_id': widget.property.id,
        'is_sold': 1,
      });
      await ref.read(propertyListingsProvider.notifier).reload();
      ref.invalidate(propertyDetailProvider(widget.property.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعليم المنشور كـ تم البيع')),
      );
    } on VewoApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busySold = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final property = widget.property;
    final auth = ref.watch(authControllerProvider);
    final isAuth = auth.isAuthenticated;
    final fav = ref.watch(favoritesControllerProvider);
    final isFav = fav.contains(property.id);
    final supportPhone =
        ref.watch(appBootstrapProvider).value?.supportPhone ?? '07871456361';
    final contactPhone =
        property.isOfficePublisher &&
            (property.ownerPhone ?? '').trim().isNotEmpty
        ? property.ownerPhone!.trim()
        : supportPhone;
    final myId = auth.userId;
    final isMine =
        myId != null &&
        property.ownerUserId != null &&
        myId == property.ownerUserId;
    final compoundName =
        (property.compoundName ??
                property.detailsJson?['compound_name']?.toString())
            ?.trim() ??
        '';

    final vx = Theme.of(context).extension<VewoExtras>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(title: const AppBarBrandTitle('تفاصيل العقار')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _MediaGallery(
            images: property.images,
            videoUrl: property.videoUrl,
            videoTrimStartSeconds: property.videoTrimStartSeconds,
            videoTrimEndSeconds: property.videoTrimEndSeconds,
            propertyCode: property.publicNo,
          ),
          const SizedBox(height: 14),
          if (property.publicNo != null) ...[
            Material(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _copyPublicNo(property.publicNo!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tag_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رقم المنشور',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '#${property.publicNo}',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.copy_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                _PropertySpecTile(
                  icon: Icons.location_on_outlined,
                  label: 'الموقع',
                  value:
                      '${property.governorate}${property.addressLine.trim().isEmpty ? '' : ' — ${property.addressLine.trim()}'}',
                ),
                if (propertyLatLng(property) != null) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: PropertyMapEmbed(
                      center: propertyLatLng(property)!,
                      height: 220,
                    ),
                  ),
                ],
                const Divider(height: 1),
                _PropertySpecTile(
                  icon: Icons.category_outlined,
                  label: 'نوع العقار',
                  value: property.category.labelAr,
                ),
                if (!(property.segment == PropertySegment.parcel &&
                    property.areaSqm <= 1)) ...[
                  const Divider(height: 1),
                  _PropertySpecTile(
                    icon: Icons.straighten_rounded,
                    label: 'المساحة',
                    value: '${property.areaSqm} م²',
                  ),
                ],
                const Divider(height: 1),
                _PropertySpecTile(
                  icon: property.purpose == 'rent'
                      ? Icons.key_rounded
                      : Icons.sell_outlined,
                  label: 'الغرض',
                  value: property.purpose == 'rent' ? 'إيجار' : 'بيع',
                ),
                if (compoundName.isNotEmpty) ...[
                  const Divider(height: 1),
                  _PropertySpecTile(
                    icon: Icons.location_city_outlined,
                    label: 'المجمع السكني',
                    value: compoundName,
                  ),
                ],
              ],
            ),
          ),
          if (property.publisherLabel.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  property.publisherVerified
                      ? Icons.verified_rounded
                      : Icons.person_outline_rounded,
                  size: 20,
                  color: property.publisherVerified
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    property.publisherLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (_negotiableFlag) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Chip(
                label: const Text('قابل للتفاوض'),
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  Icons.handshake_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
          if (property.detailsJson != null &&
              property.detailsJson!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fact_check_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'تفاصيل إضافية',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._detailLines(property.detailsJson!),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            property.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black87,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(
                    'السعر',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (property.priceIqd <= 0)
                    Text(
                      'حسب الاتفاق',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  else
                    Text(
                      IQDFormatter.format(property.priceIqd),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_negotiableFlag && property.priceIqd > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Chip(
                avatar: const Icon(Icons.handshake_outlined, size: 18),
                label: const Text('السعر قابل للتفاوض'),
              ),
            ),
          ],
          if (isMine && property.isApproved) ...[
            const SizedBox(height: 16),
            if (property.isSold)
              Material(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sell_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'هذا المنشور معلَّم كـ «تم البيع» ويظهر الشريط الأزرق على الصورة.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              FilledButton.icon(
                onPressed: _busySold ? null : _markSold,
                icon: _busySold
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(_busySold ? 'جاري التحديث…' : 'تم البيع'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        vx?.success ?? Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    final raw = contactPhone.replaceAll(RegExp(r'[^\d+]'), '');
                    if (raw.isEmpty) return;
                    final uri = Uri.parse('tel:$raw');
                    try {
                      final ok = await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تعذر فتح تطبيق الاتصال'),
                          ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تعذر فتح تطبيق الاتصال'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.call_rounded, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'اتصال',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                width: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        vx?.whatsApp ?? Theme.of(context).colorScheme.tertiary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    final ok = await openWhatsAppSupport();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: SelectableText(
                            'تعذر فتح واتساب — انسخ الرابط: https://wa.me/$_kWhatsAppLaunchDigits',
                          ),
                          duration: const Duration(seconds: 8),
                        ),
                      );
                    }
                  },
                  child: SvgPicture.string(
                    _kWhatsAppMiniSvg,
                    width: 26,
                    height: 26,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: isAuth
                      ? () async {
                          if (!await ensureCanOpenPropertyChat(
                            context,
                            ref,
                            property,
                          )) {
                            return;
                          }
                          if (context.mounted) {
                            context.push(
                              '${AppRoutes.chatRoom}/new?property=${property.id}',
                            );
                          }
                        }
                      : () => openLoginScreen(context),
                  child: const Icon(Icons.forum_rounded, size: 26),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                width: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: isAuth
                      ? () => ref
                            .read(favoritesControllerProvider.notifier)
                            .toggle(property.id)
                      : () => openLoginScreen(context),
                  child: Icon(
                    isFav
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isFav ? AppColors.frameGold : null,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaGallery extends StatefulWidget {
  const _MediaGallery({
    required this.images,
    this.videoUrl,
    this.videoTrimStartSeconds,
    this.videoTrimEndSeconds,
    this.propertyCode,
  });
  final List<String> images;
  final String? videoUrl;
  final int? videoTrimStartSeconds;
  final int? videoTrimEndSeconds;
  final int? propertyCode;

  @override
  State<_MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<_MediaGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoUrl = widget.videoUrl?.trim();
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final itemCount = widget.images.length + (hasVideo ? 1 : 0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: itemCount,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                if (hasVideo && i == 0) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      PropertyVideoPlayer(
                        url: videoUrl,
                        trimStartSeconds: widget.videoTrimStartSeconds,
                        trimEndSeconds: widget.videoTrimEndSeconds,
                      ),
                      Positioned.directional(
                        textDirection: Directionality.of(context),
                        top: 10,
                        end: 10,
                        child: FloatingActionButton.small(
                          heroTag:
                              'property_video_fullscreen_${widget.propertyCode ?? 0}',
                          tooltip: 'تكبير الفيديو',
                          onPressed: () =>
                              _openVideoFullScreen(context, videoUrl),
                          backgroundColor: Colors.black.withValues(alpha: 0.62),
                          foregroundColor: Colors.white,
                          child: const Icon(Icons.open_in_full_rounded),
                        ),
                      ),
                      Positioned.directional(
                        textDirection: Directionality.of(context),
                        end: 12,
                        bottom: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              'اضغط للتشغيل والإيقاف',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                final imageIndex = hasVideo ? i - 1 : i;
                return GestureDetector(
                  onTap: () => showPropertyImageGallery(
                    context,
                    imageUrls: widget.images,
                    initialIndex: imageIndex,
                    propertyCode: widget.propertyCode,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.images[imageIndex],
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    '${_index + 1}/$itemCount',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openVideoFullScreen(BuildContext context, String videoUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: PropertyVideoPlayer(
                url: videoUrl,
                fit: BoxFit.contain,
                trimStartSeconds: widget.videoTrimStartSeconds,
                trimEndSeconds: widget.videoTrimEndSeconds,
              ),
            ),
            Positioned.directional(
              textDirection: Directionality.of(ctx),
              top: 10,
              end: 10,
              child: SafeArea(
                child: IconButton.filled(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _detailLines(Map<String, dynamic> d) {
  String? gv(String k) {
    final v = d[k];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  bool? pickBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == '1' || s == 'true' || s == 'yes') return true;
      if (s == '0' || s == 'false' || s == 'no') return false;
    }
    return null;
  }

  final rows = <(String, String)>[];

  void add(String label, String? v) {
    if (v != null) rows.add((label, v));
  }

  void addBool(String label, bool? v) {
    if (v != null) rows.add((label, v ? 'نعم' : 'لا'));
  }

  add('واجهة (م)', gv('facade_m'));
  add('عمق / نزال (م)', gv('depth_m'));

  final b = d['building'];
  if (b is Map) {
    final m = Map<String, dynamic>.from(b);
    add('عدد الغرف', m['rooms']?.toString());
    add('الحمامات', m['bathrooms']?.toString());
    add('نوع الحمام', m['bath_type']?.toString());
    add('الصالات', m['salons']?.toString());
    final hot = pickBool(m['kitchen_hot']) == true;
    final cold = pickBool(m['kitchen_cold']) == true;
    if (hot || cold) {
      final parts = <String>[];
      if (hot) parts.add('مياه حارة');
      if (cold) parts.add('مياه باردة');
      add('المطبخ', parts.join(' — '));
    } else {
      add('المطبخ', m['kitchen']?.toString());
    }
    add('الطابق', m['floor']?.toString());
    add('عدد الطوابق', m['total_floors']?.toString());
    addBool('بلكونة', m['balcony'] is bool ? m['balcony'] as bool : null);
    addBool('مفروشة', m['furnished'] is bool ? m['furnished'] as bool : null);
    add('نوع الأرض', m['land_type']?.toString());
    add('واجهة الأرض (م)', m['land_frontage_m']?.toString());
    add('عمق الأرض (م)', m['land_depth_m']?.toString());
    add('عدد الواجهات', m['land_facades_count']?.toString());
    addBool('مزروعة', m['planted'] is bool ? m['planted'] as bool : null);
    addBool('مسوّرة', m['fenced'] is bool ? m['fenced'] as bool : null);
    add('اسم المقاطعة', m['parcel_name']?.toString());
    add('رقم المقاطعة', m['parcel_no']?.toString());
    add('رقم القطعة', m['piece_no']?.toString());
    add('الشارع', m['street_type']?.toString());
    addBool('زاوية (مقاطعة)', m['corner'] is bool ? m['corner'] as bool : null);
    add('موقع الشقة', m['apt_position']?.toString());
    addBool(
      'زاوية (شقة)',
      m['apt_corner'] is bool ? m['apt_corner'] as bool : null,
    );
    add('شقق في الطابق', m['apts_per_floor']?.toString());
    add('اتجاه الشقة', m['apt_direction']?.toString());
    addBool(
      'مصعد (شقة)',
      m['apt_elevator'] is bool ? m['apt_elevator'] as bool : null,
    );
    addBool(
      'خدمات مشتركة',
      m['apt_shared_services'] is bool
          ? m['apt_shared_services'] as bool
          : null,
    );
  }

  final s = d['services'];
  if (s is Map) {
    final m = Map<String, dynamic>.from(s);
    addBool('كهرباء', pickBool(m['electric']));
    final amps = m['electric_amps']?.toString().trim();
    if (amps != null && amps.isNotEmpty) add('أمبير الكهرباء', amps);
    addBool('طاقة شمسية', pickBool(m['solar']));
    final homeGen = pickBool(m['home_generator']);
    final legacyGen = pickBool(m['generator']);
    addBool('مولد منزلي', homeGen ?? legacyGen);
    final legacyAmps = m['generator_amps']?.toString().trim();
    if ((homeGen == true || legacyGen == true) &&
        (amps == null || amps.isEmpty) &&
        legacyAmps != null &&
        legacyAmps.isNotEmpty) {
      add('أمبير المولد', legacyAmps);
    }
    addBool('إنترنت', pickBool(m['internet']));
    add('الماء', m['water']?.toString());
    add('الصرف', m['sewage']?.toString());
  }

  final a = d['amenities'];
  if (a is Map) {
    final m = Map<String, dynamic>.from(a);
    addBool('مصعد', m['elevator'] is bool ? m['elevator'] as bool : null);
    addBool('موقف', m['parking'] is bool ? m['parking'] as bool : null);
    addBool('حديقة', m['garden'] is bool ? m['garden'] as bool : null);
    addBool('حراسة', m['guard'] is bool ? m['guard'] as bool : null);
    addBool('كاميرات', m['cctv'] is bool ? m['cctv'] as bool : null);
    addBool('إنذار', m['alarm'] is bool ? m['alarm'] as bool : null);
  }

  final f = d['features'];
  if (f is Map) {
    final m = Map<String, dynamic>.from(f);
    addBool(
      'قريب من مدرسة',
      m['near_school'] is bool ? m['near_school'] as bool : null,
    );
    addBool(
      'قريب من مستشفى',
      m['near_hospital'] is bool ? m['near_hospital'] as bool : null,
    );
    addBool(
      'قريب من سوق',
      m['near_market'] is bool ? m['near_market'] as bool : null,
    );
    addBool(
      'شارع تجاري',
      m['commercial_street'] is bool ? m['commercial_street'] as bool : null,
    );
    addBool(
      'مناسب للاستثمار',
      m['investment'] is bool ? m['investment'] as bool : null,
    );
  }

  return rows
      .map(
        (e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceMutedLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      e.$1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.$2,
                      style: const TextStyle(
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      )
      .toList();
}

class _PropertySpecTile extends StatelessWidget {
  const _PropertySpecTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
