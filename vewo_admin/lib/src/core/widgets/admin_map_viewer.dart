import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// خريطة داخلية لعرض موقع المنشور (بدون فتح تطبيق خارجي).
Future<void> showAdminPropertyMapViewer(
  BuildContext context,
  double lat,
  double lng, {
  String title = 'موقع المنشور',
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => _AdminPropertyMapPage(lat: lat, lng: lng, title: title),
    ),
  );
}

class _AdminPropertyMapPage extends StatefulWidget {
  const _AdminPropertyMapPage({
    required this.lat,
    required this.lng,
    required this.title,
  });

  final double lat;
  final double lng;
  final String title;

  @override
  State<_AdminPropertyMapPage> createState() => _AdminPropertyMapPageState();
}

class _AdminPropertyMapPageState extends State<_AdminPropertyMapPage> {
  GoogleMapController? _controller;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(widget.lat, widget.lng);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: 16),
        onMapCreated: (c) => _controller = c,
        markers: {
          Marker(
            markerId: const MarkerId('property'),
            position: center,
            infoWindow: const InfoWindow(title: 'موقع المنشور'),
          ),
        },
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        mapToolbarEnabled: false,
        gestureRecognizers: {
          Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
        },
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          _controller?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: center, zoom: 16),
            ),
          );
        },
        child: const Icon(Icons.center_focus_strong_rounded),
      ),
    );
  }
}

class AdminMapOpenTile extends StatelessWidget {
  const AdminMapOpenTile({
    super.key,
    required this.lat,
    required this.lng,
    this.height = 180,
  });

  final double lat;
  final double lng;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: scheme.surfaceContainerHighest,
        child: InkWell(
          onTap: () => showAdminPropertyMapViewer(context, lat, lng),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 42, color: scheme.primary),
                const SizedBox(height: 8),
                Text(
                  'عرض الموقع على الخريطة',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
