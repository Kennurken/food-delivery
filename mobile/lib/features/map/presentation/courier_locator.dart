import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/geo_repository.dart';
import 'device_location.dart';

/// Pushes the courier's GPS to the API while this widget is on screen.
/// Does not invent motion — if the phone stays still, the pin stays still.
class CourierLocator extends ConsumerStatefulWidget {
  const CourierLocator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CourierLocator> createState() => _CourierLocatorState();
}

class _CourierLocatorState extends ConsumerState<CourierLocator> {
  StreamSubscription<dynamic>? _sub;
  DateTime? _last;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final here = await currentLatLng();
    if (!mounted) return;
    if (here != null) await _ping(here.latitude, here.longitude, null);
    _sub = courierPositions().listen((pos) {
      unawaited(_ping(pos.latitude, pos.longitude, headingOf(pos)));
    }, onError: (_) {});
  }

  Future<void> _ping(double lat, double lng, double? heading) async {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < const Duration(seconds: 4)) {
      return;
    }
    _last = now;
    try {
      await ref
          .read(geoRepositoryProvider)
          .pingCourier(lat: lat, lng: lng, heading: heading);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
