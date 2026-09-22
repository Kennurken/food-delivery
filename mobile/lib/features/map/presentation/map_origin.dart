import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

class MapOrigin extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;

  void set(LatLng? value) => state = value;
}

final mapOriginProvider = NotifierProvider<MapOrigin, LatLng?>(MapOrigin.new);
