import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/place.dart';

class GeoRepository {
  GeoRepository(this._dio);

  final Dio _dio;

  Future<List<MapPlace>> search(
    String q, {
    double? lat,
    double? lng,
    String? lang,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/geo/search',
      queryParameters: {'q': q, 'lat': ?lat, 'lng': ?lng, 'lang': ?lang},
    );
    return [
      for (final row in res.data ?? const [])
        MapPlace.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<MapPlace> reverse(double lat, double lng, {String? lang}) async {
    final res = await _dio.get<dynamic>(
      '/api/v1/geo/reverse',
      queryParameters: {'lat': lat, 'lng': lng, 'lang': ?lang},
    );
    final data = res.data;
    if (data is Map<String, dynamic> &&
        (data['line'] as String? ?? '').isNotEmpty) {
      return MapPlace.fromJson(data);
    }
    return MapPlace(
      lat: lat,
      lng: lng,
      line: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
    );
  }

  Future<MapRoute> route({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/geo/route',
      queryParameters: {
        'from_lat': fromLat,
        'from_lng': fromLng,
        'to_lat': toLat,
        'to_lng': toLng,
      },
    );
    return MapRoute.fromJson(res.data ?? const {});
  }

  Future<void> pingCourier({
    required double lat,
    required double lng,
    double? heading,
  }) async {
    await _dio.post<void>(
      '/api/v1/courier/location',
      data: {'lat': lat, 'lng': lng, 'heading': ?heading},
    );
  }
}

final geoRepositoryProvider = Provider<GeoRepository>(
  (ref) => GeoRepository(ref.watch(dioProvider)),
);
