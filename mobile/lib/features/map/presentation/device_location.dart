import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

Future<LatLng?> currentLatLng() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever ||
        perm == LocationPermission.unableToDetermine) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
}

Stream<Position> courierPositions() => Geolocator.getPositionStream(
  locationSettings: const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 12,
  ),
);

double? headingOf(Position pos) {
  final heading = pos.heading;
  if (heading.isNaN || heading < 0 || heading > 360) return null;
  final accuracy = pos.headingAccuracy;
  if (accuracy > 45) return null;
  if (accuracy <= 0 && heading == 0) return null;
  return heading;
}
