import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/l10n/l10n.dart';
import '../data/geo_repository.dart';
import '../domain/geo.dart';
import '../domain/place.dart';
import 'city_map.dart';
import 'device_location.dart';
import 'map_pins.dart';

class AddressPickerScreen extends ConsumerStatefulWidget {
  const AddressPickerScreen({super.key, this.initial, this.initialLine});

  final LatLng? initial;
  final String? initialLine;

  @override
  ConsumerState<AddressPickerScreen> createState() =>
      _AddressPickerScreenState();
}

class _AddressPickerScreenState extends ConsumerState<AddressPickerScreen> {
  final _map = MapController();
  final _search = TextEditingController();
  final _focus = FocusNode();
  Timer? _searchDebounce;
  Timer? _reverseDebounce;
  var _gen = 0;
  var _moving = false;
  var _searching = false;
  var _locating = false;
  double _rotation = 0;
  MapPlace? _place;
  List<MapPlace> _hits = const [];

  LatLng get _start => widget.initial ?? almatyCenter;

  String get _lang {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'kk' ? 'ru' : code;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLine != null && widget.initialLine!.isNotEmpty) {
      _place = MapPlace(
        lat: _start.latitude,
        lng: _start.longitude,
        line: widget.initialLine!,
      );
    }
    _search.addListener(_onQuery);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _reverseDebounce?.cancel();
    _search.dispose();
    _focus.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onQuery() {
    _searchDebounce?.cancel();
    final q = _search.text.trim();
    if (q.length < 2) {
      setState(() => _hits = const []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      unawaited(_runSearch(q));
    });
  }

  Future<void> _runSearch(String q) async {
    setState(() => _searching = true);
    try {
      LatLng cam;
      try {
        cam = _map.camera.center;
      } catch (_) {
        cam = _start;
      }
      final hits = await ref
          .read(geoRepositoryProvider)
          .search(q, lat: cam.latitude, lng: cam.longitude, lang: _lang);
      if (!mounted) return;
      setState(() => _hits = hits);
    } catch (_) {
      if (mounted) setState(() => _hits = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onMapEvent(MapEvent event) {
    _rotation = event.camera.rotation;
    if (event is MapEventMove) {
      if (!_moving) setState(() => _moving = true);
    }
    if (event is MapEventMoveEnd) {
      setState(() => _moving = false);
      if (event.source == MapEventSource.mapController) return;
      _scheduleReverse(event.camera.center);
    }
  }

  void _scheduleReverse(LatLng center) {
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_reverse(center));
    });
  }

  Future<void> _reverse(LatLng center) async {
    final g = ++_gen;
    try {
      final place = await ref
          .read(geoRepositoryProvider)
          .reverse(center.latitude, center.longitude, lang: _lang);
      if (!mounted || g != _gen) return;
      setState(() => _place = place);
    } catch (e) {
      if (!mounted || g != _gen) return;
      setState(
        () => _place = MapPlace(
          lat: center.latitude,
          lng: center.longitude,
          line:
              '${center.latitude.toStringAsFixed(5)}, ${center.longitude.toStringAsFixed(5)}',
        ),
      );
    }
  }

  Future<void> _myLocation() async {
    setState(() => _locating = true);
    final here = await currentLatLng();
    if (!mounted) return;
    setState(() => _locating = false);
    if (here == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.locationDenied)));
      return;
    }
    _map.move(here, 16.5);
    await _reverse(here);
  }

  void _pickHit(MapPlace place) {
    _focus.unfocus();
    _search.clear();
    setState(() {
      _hits = const [];
      _place = place;
    });
    _map.move(place.point, 17);
  }

  void _confirm() {
    final cam = _map.camera.center;
    final place =
        _place ??
        MapPlace(
          lat: cam.latitude,
          lng: cam.longitude,
          line:
              '${cam.latitude.toStringAsFixed(5)}, ${cam.longitude.toStringAsFixed(5)}',
        );
    context.pop(
      MapPlace(
        lat: cam.latitude,
        lng: cam.longitude,
        line: place.line,
        subtitle: place.subtitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final line = _place?.line ?? t.dropPin;
    final sub = _place?.subtitle ?? '';

    return Scaffold(
      body: Stack(
        children: [
          CityMap(
            controller: _map,
            center: _start,
            zoom: widget.initial == null ? 13.2 : 16,
            onEvent: _onMapEvent,
            onReady: () {
              if (_place == null) _scheduleReverse(_start);
            },
          ),
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: Offset(0, _moving ? -36 : -27),
                child: MapDropPin(
                  color: scheme.primary,
                  lifting: _moving,
                  icon: Icons.place,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Material(
                          elevation: 2,
                          borderRadius: BorderRadius.circular(16),
                          color: scheme.surface,
                          child: TextField(
                            controller: _search,
                            focusNode: _focus,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: t.searchAddress,
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : (_search.text.isEmpty
                                        ? null
                                        : IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _search.clear();
                                              setState(() => _hits = const []);
                                            },
                                          )),
                              border: InputBorder.none,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_hits.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(16),
                      color: scheme.surface,
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _hits.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final h = _hits[i];
                          return ListTile(
                            leading: Icon(
                              Icons.place_outlined,
                              color: scheme.primary,
                            ),
                            title: Text(h.line),
                            subtitle: h.subtitle.isEmpty
                                ? null
                                : Text(h.subtitle),
                            onTap: () => _pickHit(h),
                          );
                        },
                      ),
                    ),
                  ] else if (_search.text.trim().length >= 2 &&
                      !_searching) ...[
                    const SizedBox(height: 8),
                    Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(16),
                      color: scheme.surface,
                      child: ListTile(
                        leading: const Icon(Icons.search_off),
                        title: Text(t.noAddressHits),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 196,
            child: Column(
              children: [
                if (_rotation.abs() > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FloatingActionButton.small(
                      heroTag: 'north',
                      onPressed: () => _map.rotate(0),
                      child: Transform.rotate(
                        angle: _rotation * 3.1415926535 / 180,
                        child: const Icon(Icons.navigation),
                      ),
                    ),
                  ),
                FloatingActionButton.small(
                  heroTag: 'me',
                  onPressed: _locating ? null : _myLocation,
                  child: _locating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ],
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
                      Text(
                        t.pickAddress,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.place, color: scheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line,
                                  style: text.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (sub.isNotEmpty)
                                  Text(
                                    sub,
                                    style: text.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _confirm,
                        child: Text(t.confirmAddress),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
