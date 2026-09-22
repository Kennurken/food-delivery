import 'package:latlong2/latlong.dart';

class MapPlace {
  const MapPlace({
    required this.lat,
    required this.lng,
    required this.line,
    this.subtitle = '',
  });

  final double lat;
  final double lng;
  final String line;
  final String subtitle;

  LatLng get point => LatLng(lat, lng);

  factory MapPlace.fromJson(Map<String, dynamic> json) => MapPlace(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    line: json['line'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
  );
}

class MapRoute {
  const MapRoute({
    required this.distanceM,
    required this.durationS,
    required this.points,
  });

  final double distanceM;
  final double durationS;
  final List<LatLng> points;

  factory MapRoute.fromJson(Map<String, dynamic> json) {
    final raw = json['points'] as List? ?? const [];
    return MapRoute(
      distanceM: (json['distance_m'] as num?)?.toDouble() ?? 0,
      durationS: (json['duration_s'] as num?)?.toDouble() ?? 0,
      points: [
        for (final p in raw)
          if (p is Map)
            LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
      ],
    );
  }
}
