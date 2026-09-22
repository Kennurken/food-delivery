import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../restaurants/domain/menu_item.dart';
import '../../restaurants/domain/restaurant.dart';

class AdminRepository {
  AdminRepository(this._dio);

  final Dio _dio;

  Future<List<Restaurant>> restaurants() async {
    final r = await _dio.get('/api/v1/admin/restaurants');
    return (r.data as List).map((e) => Restaurant.fromJson(e)).toList();
  }

  Future<Restaurant> restaurant(int id) async {
    final r = await _dio.get('/api/v1/admin/restaurants/$id');
    return Restaurant.fromJson(r.data);
  }

  Future<Restaurant> createRestaurant(Map<String, dynamic> data) async {
    final r = await _dio.post('/api/v1/admin/restaurants', data: data);
    return Restaurant.fromJson(r.data);
  }

  Future<Restaurant> updateRestaurant(
    int id,
    Map<String, dynamic> patch,
  ) async {
    final r = await _dio.patch('/api/v1/admin/restaurants/$id', data: patch);
    return Restaurant.fromJson(r.data);
  }

  Future<MenuItem> updateMenuItem(int id, Map<String, dynamic> patch) async {
    final r = await _dio.patch('/api/v1/admin/menu/$id', data: patch);
    return MenuItem.fromJson(r.data);
  }

  Future<MenuItem> createMenuItem(
    int restaurantId,
    Map<String, dynamic> data,
  ) async {
    final r = await _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/menu',
      data: data,
    );
    return MenuItem.fromJson(r.data);
  }

  Future<void> deleteMenuItem(int id) => _dio.delete('/api/v1/admin/menu/$id');
}

final adminRepositoryProvider = Provider(
  (ref) => AdminRepository(ref.watch(dioProvider)),
);

final adminRestaurantsProvider = FutureProvider<List<Restaurant>>(
  (ref) => ref.watch(adminRepositoryProvider).restaurants(),
);

final adminRestaurantProvider = FutureProvider.family<Restaurant, int>(
  (ref, id) => ref.watch(adminRepositoryProvider).restaurant(id),
);
