import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../domain/geo.dart';

const mapUserAgent = 'com.fooddelivery.food_delivery';

class CityMap extends StatelessWidget {
  const CityMap({
    super.key,
    required this.controller,
    this.center = almatyCenter,
    this.zoom = 14.5,
    this.minZoom = 4,
    this.maxZoom = 19,
    this.onEvent,
    this.onReady,
    this.layers = const [],
    this.interactive = true,
    this.attribution = true,
  });

  final MapController controller;
  final LatLng center;
  final double zoom;
  final double minZoom;
  final double maxZoom;
  final void Function(MapEvent event)? onEvent;
  final VoidCallback? onReady;
  final List<Widget> layers;
  final bool interactive;
  final bool attribution;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final retina = MediaQuery.devicePixelRatioOf(context) > 1.2;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: minZoom,
        maxZoom: maxZoom,
        backgroundColor: Theme.of(context).colorScheme.surface,
        onMapEvent: onEvent,
        onMapReady: onReady,
        keepAlive: interactive,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: dark
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: mapUserAgent,
          retinaMode: retina,
          maxNativeZoom: 19,
        ),
        ...layers,
        if (attribution)
          SimpleAttributionWidget(
            source: const Text('OpenStreetMap · CARTO'),
            alignment: Alignment.bottomLeft,
            backgroundColor: Theme.of(context).colorScheme.surface
                .withValues(alpha: 0.78),
          ),
      ],
    );
  }
}
