import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../location/location_providers.dart';
import 'aqar_town_map_marker.dart';

/// نافذة اختيار موقع: تكبير/تصغير سلس، بحث بالعنوان (جيوكودينج)، وموقعي.
Future<LatLng?> showMapLocationPicker(
  BuildContext context,
  WidgetRef ref, {
  LatLng? initial,
  String title = 'حدد الموقع على الخريطة',
  String hintSearch = 'ابحث عن موقع أو اسم العقار',
  bool showOptionalHint = false,
}) async {
  final my = ref.read(currentLatLngProvider);
  return Navigator.of(context).push<LatLng>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) {
        return _MapPickerBody(
          initial: initial ?? my ?? const LatLng(33.3152, 44.3661),
          title: title,
          hintSearch: hintSearch,
          showOptionalHint: showOptionalHint,
        );
      },
    ),
  );
}

class _MapPickerBody extends ConsumerStatefulWidget {
  const _MapPickerBody({
    required this.initial,
    required this.title,
    required this.hintSearch,
    required this.showOptionalHint,
  });

  final LatLng initial;
  final String title;
  final String hintSearch;
  final bool showOptionalHint;

  @override
  ConsumerState<_MapPickerBody> createState() => _MapPickerBodyState();
}

class _MapPickerBodyState extends ConsumerState<_MapPickerBody> {
  late LatLng _marker;
  GoogleMapController? _map;
  var _mapType = MapType.normal;
  final _search = TextEditingController();
  bool _searching = false;
  bool _centeringOnMe = false;
  String? _searchError;
  BitmapDescriptor _markerIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueYellow,
  );

  @override
  void initState() {
    super.initState();
    _marker = widget.initial;
    createAqarTownMapMarker(size: 56, selected: true).then((icon) {
      if (mounted) setState(() => _markerIcon = icon);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnMyLocation());
  }

  Future<void> _centerOnMyLocation() async {
    if (_centeringOnMe) return;
    setState(() => _centeringOnMe = true);
    try {
      final p = await ref.read(currentPositionProvider.future);
      if (p == null || !mounted) {
        if (mounted) setState(() => _centeringOnMe = false);
        return;
      }
      final pos = LatLng(p.latitude, p.longitude);
      setState(() => _marker = pos);
      await _map?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 16)),
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _centeringOnMe = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _search.text.trim();
    if (q.length < 2) {
      setState(() => _searchError = 'اكتب 2 أحرف على الأقل');
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final query = q.contains('العراق') || q.toLowerCase().contains('iraq')
          ? q
          : '$q, العراق';
      var list = await locationFromAddress(query);
      if (!mounted) return;
      if (list.isEmpty) {
        setState(() {
          _searching = false;
          _searchError = 'لم نجد نتائج — جرّب اسم أدق';
        });
        return;
      }
      final my = ref.read(currentLatLngProvider);
      if (my != null && list.length > 1) {
        double d2(double latA, double lngA, double latB, double lngB) {
          final dx = latA - latB;
          final dy = lngA - lngB;
          return dx * dx + dy * dy;
        }

        list = [...list]
          ..sort((a, b) {
            final da = d2(my.latitude, my.longitude, a.latitude, a.longitude);
            final db = d2(my.latitude, my.longitude, b.latitude, b.longitude);
            return da.compareTo(db);
          });
      }
      final loc = list.first;
      final pos = LatLng(loc.latitude, loc.longitude);
      setState(() {
        _marker = pos;
        _searching = false;
      });
      await _map?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 15)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = 'تعذر البحث — جرّب لاحقاً أو عيّن يدوياً';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _mapType == MapType.terrain ? 'طبيعي' : 'تضاريس',
                    onPressed: () => setState(
                      () => _mapType = _mapType == MapType.terrain
                          ? MapType.normal
                          : MapType.terrain,
                    ),
                    icon: Icon(
                      _mapType == MapType.terrain
                          ? Icons.layers_outlined
                          : Icons.terrain_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: 'موقعي',
                    onPressed: _centerOnMyLocation,
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                ],
              ),
            ),
            if (widget.showOptionalHint)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  'اختياري — يمكنك التكبير والسحب ثم وضع العلامة',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _runSearch(),
                      decoration: InputDecoration(
                        hintText: widget.hintSearch,
                        prefixIcon: const Icon(Icons.search_rounded),
                        errorText: _searchError,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _searching ? null : _runSearch,
                    icon: _searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.travel_explore_rounded),
                    label: const Text('بحث'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GoogleMap(
                      gestureRecognizers:
                          <Factory<OneSequenceGestureRecognizer>>{
                            Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer(),
                            ),
                          },
                      initialCameraPosition: CameraPosition(
                        target: _marker,
                        zoom: 14,
                      ),
                      mapType: _mapType,
                      minMaxZoomPreference: const MinMaxZoomPreference(4, 22),
                      liteModeEnabled: false,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                      compassEnabled: true,
                      mapToolbarEnabled: false,
                      scrollGesturesEnabled: true,
                      zoomGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      onMapCreated: (c) {
                        _map = c;
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _centerOnMyLocation(),
                        );
                      },
                      onTap: (pos) => setState(() => _marker = pos),
                      markers: {
                        Marker(
                          markerId: const MarkerId('pick'),
                          position: _marker,
                          icon: _markerIcon,
                          draggable: true,
                          onDragEnd: (pos) => setState(() => _marker = pos),
                        ),
                      },
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 86,
                    child: FloatingActionButton.small(
                      heroTag: 'map_picker_my_location',
                      tooltip: 'موقعي الحالي',
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
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surface,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(context, _marker),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('حفظ الموقع'),
                          ),
                        ),
                      ],
                    ),
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
