import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Republic Square, Almaty — default camera for Kazakhstan.
const almatyCenter = LatLng(43.238949, 76.945465);

double metersBetween(LatLng a, LatLng b) {
  const r = 6371000.0;
  final p1 = a.latitude * math.pi / 180;
  final p2 = b.latitude * math.pi / 180;
  final dPhi = (b.latitude - a.latitude) * math.pi / 180;
  final dLmb = (b.longitude - a.longitude) * math.pi / 180;
  final h =
      math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dLmb / 2) * math.sin(dLmb / 2);
  return 2 * r * math.asin(math.sqrt(h.clamp(0, 1)));
}

String formatMeters(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return km >= 10 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
}

double? readCoord(dynamic value) => value is num ? value.toDouble() : null;

bool hasPin(double? lat, double? lng) =>
    lat != null &&
    lng != null &&
    lat.abs() <= 90 &&
    lng.abs() <= 180 &&
    !(lat == 0 && lng == 0);
