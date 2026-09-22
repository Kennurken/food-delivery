import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'city_map.dart';
import 'map_pins.dart';

class RestaurantMapPreview extends StatefulWidget {
  const RestaurantMapPreview({
    super.key,
    required this.lat,
    required this.lng,
    this.height = 148,
  });

  final double lat;
  final double lng;
  final double height;

  @override
  State<RestaurantMapPreview> createState() => _RestaurantMapPreviewState();
}

class _RestaurantMapPreviewState extends State<RestaurantMapPreview> {
  final _map = MapController();

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(widget.lat, widget.lng);
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: CityMap(
          controller: _map,
          center: point,
          zoom: 15.4,
          interactive: false,
          attribution: false,
          layers: [
            MarkerLayer(
              markers: [
                PlaceMarker.drop(
                  point: point,
                  color: scheme.primary,
                  icon: Icons.storefront,
                  size: 40,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
