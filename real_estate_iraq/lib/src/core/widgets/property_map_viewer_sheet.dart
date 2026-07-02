import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../location/location_providers.dart';
import 'aqar_town_map_marker.dart';

/// خريطة تفاعلية (تكبير/تصغير سلس، سحب، موقعي) لعرض موقع المنشور.
Future<void> showPropertyMapViewerSheet(
  BuildContext context,
  LatLng center,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => _InteractiveMapSheet(center: center),
  );
}

class _InteractiveMapSheet extends ConsumerStatefulWidget {
  const _InteractiveMapSheet({required this.center});

  final LatLng center;

  @override
  ConsumerState<_InteractiveMapSheet> createState() =>
      _InteractiveMapSheetState();
}

class _InteractiveMapSheetState extends ConsumerState<_InteractiveMapSheet> {
  GoogleMapController? _ctl;
  BitmapDescriptor _markerIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueYellow,
  );

  @override
  void initState() {
    super.initState();
    createAqarTownMapMarker(size: 56).then((icon) {
      if (mounted) setState(() => _markerIcon = icon);
    });
  }

  Future<void> _goMyLocation() async {
    try {
      final p = await ref.refresh(currentPositionProvider.future);
      if (p == null || !mounted) return;
      final pos = LatLng(p.latitude, p.longitude);
      await _ctl?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 15)),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'موقع المنشور على الخريطة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'الاقتراب من موقعي',
                  onPressed: _goMyLocation,
                  icon: const Icon(Icons.my_location_rounded),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: widget.center,
                    zoom: 15,
                  ),
                  minMaxZoomPreference: const MinMaxZoomPreference(4, 22),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  mapToolbarEnabled: false,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  onMapCreated: (c) => _ctl = c,
                  markers: {
                    Marker(
                      markerId: const MarkerId('prop'),
                      position: widget.center,
                      icon: _markerIcon,
                    ),
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
