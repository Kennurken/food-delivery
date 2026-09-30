import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/admin_city.dart';

/// City management for the platform admin. The API refuses everyone else.
class CitiesAdminRepository {
  CitiesAdminRepository(this._dio);

  final Dio _dio;

  /// Every city, switched-off ones included.
  Future<List<AdminCity>> all() async {
    final r = await _dio.get('/api/v1/admin/cities');
    return (r.data as List).map((e) => AdminCity.fromJson(e)).toList();
  }

  Future<AdminCity> create({
    required String slug,
    required String name,
    String? nameIn,
  }) async {
    final r = await _dio.post(
      '/api/v1/admin/cities',
      data: {'slug': slug, 'name': name, 'name_in': ?nameIn},
    );
    return AdminCity.fromJson(r.data);
  }

  Future<AdminCity> update(int id, Map<String, dynamic> changes) async {
    final r = await _dio.patch('/api/v1/admin/cities/$id', data: changes);
    return AdminCity.fromJson(r.data);
  }
}

final citiesAdminRepositoryProvider = Provider<CitiesAdminRepository>(
  (ref) => CitiesAdminRepository(ref.watch(dioProvider)),
);

final adminCitiesProvider = FutureProvider<List<AdminCity>>(
  (ref) => ref.watch(citiesAdminRepositoryProvider).all(),
);
