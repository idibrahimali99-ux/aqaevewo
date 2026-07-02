import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/properties/domain/property.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

LatLng? propertyLatLng(Property p) {
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

double _degToRad(double d) => d * pi / 180.0;

/// Haversine distance in meters.
double distanceMeters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = _degToRad(b.latitude - a.latitude);
  final dLng = _degToRad(b.longitude - a.longitude);
  final s1 = sin(dLat / 2);
  final s2 = sin(dLng / 2);
  final h = s1 * s1 +
      cos(_degToRad(a.latitude)) * cos(_degToRad(b.latitude)) * s2 * s2;
  return 2 * r * asin(min(1.0, sqrt(h)));
}

/// يطلب صلاحية الموقع ويُرجع Position أو null (في حال رفض/تعطيل).
final currentPositionProvider = FutureProvider.autoDispose<Position?>((ref) async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) return null;

  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    return null;
  }

  const settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 8),
  );
  return Geolocator.getCurrentPosition(locationSettings: settings);
});

final currentLatLngProvider = Provider.autoDispose<LatLng?>((ref) {
  final p = ref.watch(currentPositionProvider).valueOrNull;
  if (p == null) return null;
  return LatLng(p.latitude, p.longitude);
});

/// يحاول استخراج اسم المحافظة بالعربي قدر الإمكان.
final currentGovernorateProvider = FutureProvider.autoDispose<String?>((ref) async {
  final p = ref.watch(currentPositionProvider).valueOrNull;
  if (p == null) return null;
  try {
    final list = await placemarkFromCoordinates(p.latitude, p.longitude);
    if (list.isEmpty) return null;
    final pm = list.first;
    final parts = <String>[
      pm.administrativeArea ?? '',
      pm.subAdministrativeArea ?? '',
      pm.locality ?? '',
    ].where((e) => e.trim().isNotEmpty).toList();
    if (parts.isEmpty) return null;
    // غالباً administrativeArea هي المحافظة.
    return parts.first.trim();
  } catch (_) {
    return null;
  }
});

