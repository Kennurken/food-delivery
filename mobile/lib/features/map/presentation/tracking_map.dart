import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../data/geo_repository.dart';
import '../domain/geo.dart';
import '../domain/place.dart';
import 'city_map.dart';
import 'map_pins.dart';

class TrackingMapScreen extends ConsumerStatefulWidget {
  const TrackingMapScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<TrackingMapScreen> createState() => _TrackingMapScreenState();
}

class _TrackingMapScreenState extends ConsumerState<TrackingMapScreen> {
  final _map = MapController();
  MapRoute? _route;
  LatLng? _routedFrom;
  var _fitted = false;
  var _follow = true;
  var _ready = false;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  LatLng? _point(double? lat, double? lng) =>
      hasPin(lat, lng) ? LatLng(lat!, lng!) : null;

  Future<void> _syncRoute(Order o) async {
    final dest = _point(o.destLat, o.destLng);
    final pickup = _point(o.pickupLat, o.pickupLng);
    final courier = _point(o.courierLat, o.courierLng);
    final from = courier ?? pickup;
    final to = dest ?? pickup;
    if (from == null || to == null) return;
    if (_routedFrom != null && metersBetween(_routedFrom!, from) < 70) return;
    try {
      final route = await ref
          .read(geoRepositoryProvider)
          .route(
            fromLat: from.latitude,
            fromLng: from.longitude,
            toLat: to.latitude,
            toLng: to.longitude,
          );
      if (!mounted) return;
      setState(() {
        _route = route;
        _routedFrom = from;
      });
      _fit(route.points, dest, pickup, courier);
    } catch (_) {
      if (!mounted) return;
      final pts = [from, to];
      setState(() {
        _route = MapRoute(
          distanceM: metersBetween(from, to),
          durationS: 0,
          points: pts,
        );
        _routedFrom = from;
      });
      _fit(pts, dest, pickup, courier);
    }
  }

  void _fit(List<LatLng> pts, LatLng? dest, LatLng? pickup, LatLng? courier) {
    if (!_ready) return;
    final all = <LatLng>[...pts, ?dest, ?pickup, ?courier];
    if (all.length < 2) {
      _map.move(all.isEmpty ? almatyCenter : all.first, 15);
      return;
    }
    if (_fitted && !_follow) return;
    _fitted = true;
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(all),
        padding: const EdgeInsets.fromLTRB(48, 96, 48, 220),
        maxZoom: 16.5,
      ),
    );
  }

  void _maybeFollow(Order o) {
    if (!_follow || !_ready) return;
    final courier = _point(o.courierLat, o.courierLng);
    if (courier == null) return;
    _map.move(courier, _map.camera.zoom < 14 ? 15 : _map.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(orderLiveProvider(widget.orderId));
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    ref.listen(orderLiveProvider(widget.orderId), (prev, next) {
      final o = next.value;
      if (o == null) return;
      unawaited(_syncRoute(o));
      _maybeFollow(o);
    });

    return Scaffold(
      body: live.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (o) {
          final dest = _point(o.destLat, o.destLng);
          final pickup = _point(o.pickupLat, o.pickupLng);
          final courier = _point(o.courierLat, o.courierLng);
          final etaMin = ((_route?.durationS ?? 0) / 60).round();
          final dist = _route?.distanceM;

          return Stack(
            children: [
              CityMap(
                controller: _map,
                center: courier ?? dest ?? pickup ?? almatyCenter,
                zoom: 14.5,
                onReady: () {
                  _ready = true;
                  unawaited(_syncRoute(o));
                },
                onEvent: (e) {
                  if (e is MapEventMove &&
                      e.source != MapEventSource.mapController) {
                    if (_follow) setState(() => _follow = false);
                  }
                },
                layers: [
                  if (_route != null && _route!.points.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _route!.points,
                          strokeWidth: 5.5,
                          color: scheme.primary,
                          borderStrokeWidth: 3,
                          borderColor: Colors.white,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (pickup != null)
                        PlaceMarker.drop(
                          point: pickup,
                          color: scheme.tertiary,
                          icon: Icons.storefront,
                          size: 40,
                        ),
                      if (dest != null)
                        PlaceMarker.drop(
                          point: dest,
                          color: scheme.primary,
                          icon: Icons.home,
                        ),
                      if (courier != null)
                        PlaceMarker.courier(
                          point: courier,
                          color: scheme.secondary,
                          heading: o.courierHeading,
                        ),
                    ],
                  ),
                ],
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Spacer(),
                      FloatingActionButton.small(
                        heroTag: 'recenter',
                        onPressed: () {
                          setState(() {
                            _follow = true;
                            _fitted = false;
                          });
                          unawaited(_syncRoute(o));
                        },
                        child: Icon(
                          _follow ? Icons.gps_fixed : Icons.gps_not_fixed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  elevation: 12,
                  color: scheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: scheme.outlineVariant,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  o.restaurantName,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                o.statusLabel(t),
                                style: text.labelLarge?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(o.address, style: text.bodySmall),
                          if (o.courier != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              t.toastCourier(o.courier!.name),
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (dist != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              etaMin > 0
                                  ? '${formatDistance(t, dist)} · ${t.minutes(etaMin)}'
                                  : formatDistance(t, dist),
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            o.statusHint(t),
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
