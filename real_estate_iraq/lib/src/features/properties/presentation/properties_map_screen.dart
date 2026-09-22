import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:vewo_shared/vewo_shared.dart' show IQDFormatter;
import '../domain/property.dart';
import '../data/properties_providers.dart';
import '../../../core/location/location_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/property_video_player.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';

LatLng? _propertyLatLng(Property p) {
  final d = p.detailsJson;
  if (d == null) return null;
  final loc = d['location'];
  final m = loc is Map<String, dynamic>
      ? loc
      : (loc is Map ? Map<String, dynamic>.from(loc) : null);
  if (m == null) return null;
  final latRaw = m['lat'];
  final lngRaw = m['lng'];
  final lat = latRaw is num ? latRaw.toDouble() : double.tryParse('$latRaw');
  final lng = lngRaw is num ? lngRaw.toDouble() : double.tryParse('$lngRaw');
  if (lat == null || lng == null) return null;
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return LatLng(lat, lng);
}

Future<BitmapDescriptor> _aqarTownMarker({
  required double size,
  bool selected = false,
  IconData icon = Icons.home_work_rounded,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..isAntiAlias = true;
  final center = Offset(size / 2, size / 2);
  final radius = size * 0.32;

  paint.color = Colors.black.withValues(alpha: 0.16);
  canvas.drawCircle(center.translate(0, size * 0.08), radius * 1.02, paint);

  paint.color = selected ? AppColors.brandPrimary : AppColors.mapPin;
  canvas.drawCircle(center, radius, paint);

  paint
    ..style = PaintingStyle.stroke
    ..strokeWidth = selected ? 5 : 3
    ..color = Colors.white.withValues(alpha: selected ? 0.95 : 0.72);
  canvas.drawCircle(center, radius - paint.strokeWidth, paint);
  paint.style = PaintingStyle.fill;

  final textPainter = TextPainter(textDirection: TextDirection.ltr)
    ..text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: size * 0.32,
        color: Colors.white,
      ),
    )
    ..layout();
  textPainter.paint(
    canvas,
    center - Offset(textPainter.width / 2, textPainter.height / 2),
  );

  final pointer = Path()
    ..moveTo(center.dx - radius * 0.38, center.dy + radius * 0.72)
    ..lineTo(center.dx + radius * 0.38, center.dy + radius * 0.72)
    ..lineTo(center.dx, size * 0.92)
    ..close();
  paint.color = selected ? AppColors.brandPrimary : AppColors.mapPin;
  canvas.drawPath(pointer, paint);

  final image = await recorder.endRecording().toImage(
    size.round(),
    size.round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return BitmapDescriptor.bytes(bytes?.buffer.asUint8List() ?? Uint8List(0));
}

LatLngBounds? _boundsFor(List<LatLng> points) {
  if (points.isEmpty) return null;
  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;
  for (final p in points.skip(1)) {
    minLat = min(minLat, p.latitude);
    maxLat = max(maxLat, p.latitude);
    minLng = min(minLng, p.longitude);
    maxLng = max(maxLng, p.longitude);
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

class PropertiesMapScreen extends ConsumerStatefulWidget {
  const PropertiesMapScreen({super.key});

  @override
  ConsumerState<PropertiesMapScreen> createState() =>
      _PropertiesMapScreenState();
}

class _PropertiesMapScreenState extends ConsumerState<PropertiesMapScreen> {
  GoogleMapController? _map;
  String? _selectedId;
  double _mapZoom = 6.2;
  bool _centeringOnMe = false;
  BitmapDescriptor _propertyMarker = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueYellow,
  );
  BitmapDescriptor _selectedMarker = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueYellow,
  );
  BitmapDescriptor _clusterMarker = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueYellow,
  );

  @override
  void initState() {
    super.initState();
    _loadAqarTownMarkers();
  }

  Future<void> _loadAqarTownMarkers() async {
    final property = await _aqarTownMarker(size: 56);
    final selected = await _aqarTownMarker(size: 62, selected: true);
    final cluster = await _aqarTownMarker(
      size: 59,
      icon: Icons.apartment_rounded,
    );
    if (!mounted) return;
    setState(() {
      _propertyMarker = property;
      _selectedMarker = selected;
      _clusterMarker = cluster;
    });
  }

  int _gridPrecisionForZoom(double z) {
    if (z >= 14) return 4;
    if (z >= 12) return 3;
    if (z >= 10) return 2;
    return 1;
  }

  /// تجميع بسيط حسب الشبكة: بعيداً = عدّادات، قريباً = علامات منفصلة.
  List<({LatLng center, List<Property> props})> _clustered(
    List<Property> items,
  ) {
    final prec = _gridPrecisionForZoom(_mapZoom);
    final factor = pow(10, prec).toDouble();
    final buckets = <String, List<Property>>{};
    for (final p in items) {
      final ll = _propertyLatLng(p);
      if (ll == null) continue;
      final la = (ll.latitude * factor).round() / factor;
      final ln = (ll.longitude * factor).round() / factor;
      final key = '$la|$ln';
      buckets.putIfAbsent(key, () => []).add(p);
    }
    final out = <({LatLng center, List<Property> props})>[];
    for (final e in buckets.entries) {
      final pts = e.value.map(_propertyLatLng).whereType<LatLng>().toList();
      if (pts.isEmpty) continue;
      var sl = 0.0;
      var sn = 0.0;
      for (final q in pts) {
        sl += q.latitude;
        sn += q.longitude;
      }
      final c = LatLng(sl / pts.length, sn / pts.length);
      out.add((center: c, props: e.value));
    }
    return out;
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _fitAll(List<LatLng> pts) async {
    final controller = _map;
    if (controller == null) return;
    final b = _boundsFor(pts);
    if (b == null) return;
    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(b, 48));
    } catch (_) {
      // ignore (can fail if map not laid out yet)
    }
  }

  Future<void> _centerOnMyLocation() async {
    if (_centeringOnMe) return;
    setState(() => _centeringOnMe = true);
    try {
      final p = await ref.read(currentPositionProvider.future);
      if (p == null || !mounted || _map == null) return;
      await _map!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(p.latitude, p.longitude), zoom: 16),
        ),
      );
    } finally {
      if (mounted) setState(() => _centeringOnMe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(allPropertiesProvider);
    final loading = ref.watch(propertyListingsLoadingProvider);
    final focusId = GoRouterState.of(context).uri.queryParameters['focus'];
    Property? selectedProperty;
    for (final p in items) {
      if (p.id == _selectedId) {
        selectedProperty = p;
        break;
      }
    }
    if (focusId != null &&
        focusId.trim().isNotEmpty &&
        _selectedId != focusId) {
      // عند فتح الخريطة من تفاصيل منشور: ركّز على المنشور وافتح الكرت المصغّر.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        Property? prop;
        for (final it in items) {
          if (it.id == focusId) {
            prop = it;
            break;
          }
        }
        if (prop == null) return;
        final pos = _propertyLatLng(prop);
        if (pos != null && _map != null) {
          try {
            await _map!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: pos, zoom: 16),
              ),
            );
          } catch (_) {}
        }
        if (!context.mounted) return;
        setState(() => _selectedId = focusId);
      });
    }

    final points = <LatLng>[];
    for (final p in items) {
      final pos = _propertyLatLng(p);
      if (pos != null) points.add(pos);
    }
    final clusters = _clustered(items);
    final markers = <Marker>{};
    for (final cl in clusters) {
      final group = cl.props;
      final pos = cl.center;
      if (group.length == 1) {
        final p = group.first;
        markers.add(
          Marker(
            markerId: MarkerId(p.id),
            position: pos,
            onTap: () {
              setState(() => _selectedId = p.id);
            },
            icon: _selectedId == p.id ? _selectedMarker : _propertyMarker,
          ),
        );
      } else {
        final cid =
            'c_${pos.latitude.toStringAsFixed(4)}_${pos.longitude.toStringAsFixed(4)}';
        markers.add(
          Marker(
            markerId: MarkerId(cid),
            position: pos,
            onTap: () async {
              setState(() => _selectedId = null);
              final controller = _map;
              if (controller == null) return;
              await controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: pos, zoom: min(_mapZoom + 2.2, 18)),
                ),
              );
            },
            icon: _clusterMarker,
            infoWindow: InfoWindow(
              title: '${group.length} منشور',
              snippet: 'اضغط لعرض القائمة',
            ),
          ),
        );
      }
    }

    final scheme = Theme.of(context).colorScheme;
    final hasAny = points.isNotEmpty;
    const baghdad = LatLng(33.3152, 44.3661);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: baghdad,
                zoom: 6.2,
              ),
              minMaxZoomPreference: const MinMaxZoomPreference(4, 22),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              compassEnabled: true,
              mapToolbarEnabled: false,
              markers: markers,
              onTap: (_) {
                if (_selectedId != null) setState(() => _selectedId = null);
              },
              onCameraMove: (pos) => _mapZoom = pos.zoom,
              onCameraIdle: () {
                if (mounted) setState(() {});
              },
              onMapCreated: (c) {
                _map = c;
                if (hasAny) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _fitAll(points);
                  });
                }
              },
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Material(
              elevation: 12,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(20),
              color: scheme.surface.withValues(alpha: 0.94),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const AppBarBrandTitle('الخريطة'),
                    const Spacer(),
                    Text(
                      hasAny
                          ? '${points.length} منشور'
                          : loading
                          ? 'جاري التحميل'
                          : 'لا توجد مواقع',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'تحديث',
                      onPressed: () =>
                          ref.read(propertyListingsProvider.notifier).reload(),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'عرض الكل',
                      onPressed: hasAny ? () => _fitAll(points) : null,
                      icon: const Icon(Icons.center_focus_strong_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!hasAny)
            Positioned(
              left: 20,
              right: 20,
              bottom: 120,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(18),
                color: scheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (loading)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(Icons.place_outlined, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          loading
                              ? 'جاري تحميل المنشورات على الخريطة...'
                              : 'لا توجد مواقع متاحة على الخريطة حالياً.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (selectedProperty != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 104 + MediaQuery.paddingOf(context).bottom,
              child: _MapPropertyPopup(
                property: selectedProperty,
                onClose: () => setState(() => _selectedId = null),
                onTap: () => context.push(
                  '${AppRoutes.propertyDetails}/${selectedProperty!.id}',
                ),
              ),
            )
          else
            Positioned(
              left: 20,
              right: 20,
              bottom: 120,
              child: IgnorePointer(
                ignoring: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Colors.black.withValues(alpha: 0.48),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.touch_app_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'اضغط على أي نقطة لعرض تفاصيل المنشور',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 20,
            bottom: 188,
            child: FloatingActionButton.small(
              heroTag: 'properties_map_my_location',
              tooltip: 'موقعي الحالي',
              backgroundColor: scheme.surface,
              foregroundColor: scheme.primary,
              onPressed: _centeringOnMe ? null : _centerOnMyLocation,
              child: _centeringOnMe
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPropertyPopup extends StatelessWidget {
  const _MapPropertyPopup({
    required this.property,
    required this.onTap,
    required this.onClose,
  });

  final Property property;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = property.title.trim().isNotEmpty
        ? property.title.trim()
        : property.displayCategoryAr;
    final price = property.priceIqd > 0
        ? IQDFormatter.format(property.priceIqd)
        : 'حسب الاتفاق';
    final video = property.videoUrl?.trim();
    final hasVideo = video != null && video.isNotEmpty;
    final imageUrl = property.images.isNotEmpty ? property.images.first : '';

    return Material(
      color: Colors.transparent,
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 188),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: 128,
                height: 188,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasVideo)
                      PropertyVideoPlayer(
                        url: video,
                        trimStartSeconds: property.videoTrimStartSeconds,
                        trimEndSeconds: property.videoTrimEndSeconds,
                      )
                    else if (imageUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      )
                    else
                      ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: scheme.outline,
                        ),
                      ),
                    if (hasVideo)
                      PositionedDirectional(
                        top: 10,
                        start: 10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.58),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_outline,
                                  color: Colors.white,
                                  size: 15,
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'فيديو',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: onClose,
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.frameGold,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.mapPin,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              property.governorate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton.tonalIcon(
                          onPressed: onTap,
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('عرض التفاصيل'),
                        ),
                      ),
                    ],
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
