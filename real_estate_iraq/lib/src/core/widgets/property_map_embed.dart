import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'aqar_town_map_marker.dart';
import 'property_map_viewer_sheet.dart';

/// خريطة مضمّنة قابلة للتكبير/التصغير — تفتح ورقة كاملة عند الضغط.
class PropertyMapEmbed extends StatefulWidget {
  const PropertyMapEmbed({
    super.key,
    required this.center,
    this.height = 200,
    this.borderRadius = 18,
  });

  final LatLng center;
  final double height;
  final double borderRadius;

  @override
  State<PropertyMapEmbed> createState() => _PropertyMapEmbedState();
}

class _PropertyMapEmbedState extends State<PropertyMapEmbed> {
  BitmapDescriptor _markerIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueYellow,
  );

  @override
  void initState() {
    super.initState();
    createAqarTownMapMarker(size: 52).then((icon) {
      if (mounted) setState(() => _markerIcon = icon);
    }).catchError((_) {
      // نبقى على العلامة الافتراضية — لا نُسقط الشاشة على iOS.
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.center,
                zoom: 15,
              ),
              minMaxZoomPreference: const MinMaxZoomPreference(4, 22),
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              zoomControlsEnabled: true,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              liteModeEnabled: false,
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              markers: {
                Marker(
                  markerId: const MarkerId('property'),
                  position: widget.center,
                  icon: _markerIcon,
                ),
              },
            ),
            Positioned(
              left: 8,
              top: 8,
              child: Material(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: () =>
                      showPropertyMapViewerSheet(context, widget.center),
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_full_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'تكبير الخريطة',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
