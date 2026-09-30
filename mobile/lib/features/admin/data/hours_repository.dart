import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../restaurants/domain/opening_hours.dart';

class HoursRepository {
  HoursRepository(this._dio);

  final Dio _dio;

  Future<List<OpeningStretch>> week(int restaurantId) async {
    final resp = await _dio.get('/api/v1/restaurants/$restaurantId/hours');
    final data = resp.data as List<dynamic>;
    return [
      for (final h in data) OpeningStretch.fromJson(h as Map<String, dynamic>),
    ];
  }

  Future<List<OpeningStretch>> save(
    int restaurantId,
    List<OpeningStretch> week,
  ) async {
    final resp = await _dio.put(
      '/api/v1/admin/restaurants/$restaurantId/hours',
      data: [for (final s in week) s.toJson()],
    );
    final data = resp.data as List<dynamic>;
    return [
      for (final h in data) OpeningStretch.fromJson(h as Map<String, dynamic>),
    ];
  }
}

final hoursRepositoryProvider = Provider<HoursRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return HoursRepository(dio);
});
