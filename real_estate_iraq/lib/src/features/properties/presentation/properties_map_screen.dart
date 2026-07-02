import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/property.dart';
import '../data/properties_providers.dart';
import 'property_card.dart';
import '../../../core/api/app_bootstrap_provider.dart';
import '../../../core/location/location_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../../../routing/app_routes.dart';
import '../../auth/data/auth_controller.dart';
import '../../../routing/auth_nav.dart';

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

  void _openMiniSheet(
    BuildContext context,
    Property p, {
    required String supportPhone,
    required bool isAuth,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        Future<void> callSupport() async {
          final raw = supportPhone.replaceAll(RegExp(r'[^\d+]'), '');
          if (raw.isEmpty) return;
          final uri = Uri.parse('tel:$raw');
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!ok && ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('تعذر فتح تطبيق الاتصال')),
            );
          }
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openFullSheet(context, p);
                  },
                  child: SizedBox(
                    height: 180,
                    child: PropertyCard(
                      property: p,
                      showMapPreview: false,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        context.push('${AppRoutes.propertyDetails}/${p.id}');
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: supportPhone.isEmpty ? null : callSupport,
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('تواصل'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isAuth
                            ? () {
                                Navigator.of(ctx).pop();
                                context.push(
                                  '${AppRoutes.chatRoom}/new?property=${p.id}',
                                );
                              }
                            : () {
                                Navigator.of(ctx).pop();
                                openLoginScreen(context);
                              },
                        icon: const Icon(Icons.forum_rounded),
                        label: const Text('محادثة'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFullSheet(BuildContext context, Property p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: SizedBox(
              height: 420,
              child: PropertyCard(
                property: p,
                showMapPreview: false,
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push('${AppRoutes.propertyDetails}/${p.id}');
                },
              ),
            ),
          ),
        );
      },
    );
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

  void _openClusterSheet(
    BuildContext context, {
    required List<Property> props,
    required String supportPhone,
    required bool isAuth,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: props.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (c, i) {
            final p = props[i];
            return ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: Text(
                p.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.pop(ctx);
                _openMiniSheet(
                  context,
                  p,
                  supportPhone: supportPhone,
                  isAuth: isAuth,
                );
              },
            );
          },
        ),
      ),
    );
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
    final auth = ref.watch(authControllerProvider);
    final bootstrap = ref.watch(appBootstrapProvider).valueOrNull;
    final supportPhone = (bootstrap?.supportPhone ?? '').trim();
    final focusId = GoRouterState.of(context).uri.queryParameters['focus'];
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
        if (!context.mounted) return;
        _openMiniSheet(
          context,
          prop,
          supportPhone: supportPhone,
          isAuth: auth.isAuthenticated,
        );
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
              _openMiniSheet(
                context,
                p,
                supportPhone: supportPhone,
                isAuth: auth.isAuthenticated,
              );
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
            onTap: () {
              _openClusterSheet(
                context,
                props: group,
                supportPhone: supportPhone,
                isAuth: auth.isAuthenticated,
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
