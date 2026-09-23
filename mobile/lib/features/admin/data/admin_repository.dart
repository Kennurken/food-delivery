import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../restaurants/domain/menu_item.dart';
import '../../restaurants/domain/restaurant.dart';
import '../domain/platform_venue.dart';

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

  /// Dishes currently off sale.
  Future<List<MenuItem>> stopList(int restaurantId) async {
    final r = await _dio.get(
      '/api/v1/admin/restaurants/$restaurantId/stop-list',
    );
    return (r.data as List).map((e) => MenuItem.fromJson(e)).toList();
  }

  /// Stop or restore several dishes in one call — bringing a menu back one
  /// dish at a time is how something stays off for a week.
  Future<void> setAvailability(
    int restaurantId,
    List<int> itemIds, {
    required bool available,
  }) async {
    if (itemIds.isEmpty) return;
    await _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/stop-list',
      data: {'item_ids': itemIds, 'available': available},
    );
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

  Future<MenuItem> replaceModifiers(
    int itemId,
    List<Map<String, dynamic>> groups,
  ) async {
    final r = await _dio.put(
      '/api/v1/admin/menu/$itemId/modifiers',
      data: groups,
    );
    return MenuItem.fromJson(r.data);
  }

  Future<Map<String, dynamic>> overview() async {
    final r = await _dio.get('/api/v1/platform/overview');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> workspace(int restaurantId) async {
    final r = await _dio.get(
      '/api/v1/admin/restaurants/$restaurantId/workspace',
    );
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> promos(int restaurantId) async {
    final r = await _dio.get('/api/v1/admin/restaurants/$restaurantId/promos');
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> createPromo(int restaurantId, Map<String, dynamic> data) async {
    await _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/promos',
      data: data,
    );
  }

  Future<void> setPromoActive(int promoId, bool active) async {
    await _dio.patch(
      '/api/v1/admin/promos/$promoId',
      data: {'is_active': active},
    );
  }

  Future<List<Map<String, dynamic>>> reservations(int restaurantId) async {
    final r = await _dio.get(
      '/api/v1/admin/restaurants/$restaurantId/reservations',
    );
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createReservation(
    int restaurantId,
    Map<String, dynamic> data,
  ) async {
    final r = await _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/reservations',
      data: data,
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateReservation(
    int reservationId, {
    String? status,
    int? tableObjectId,
  }) async {
    final r = await _dio.patch(
      '/api/v1/admin/reservations/$reservationId',
      data: {'status': ?status, 'table_object_id': ?tableObjectId},
    );
    return r.data as Map<String, dynamic>;
  }

  // --- platform admin directory
  Future<List<PlatformVenue>> platformVenues({String? q, int days = 30}) async {
    final r = await _dio.get(
      '/api/v1/platform/restaurants',
      queryParameters: {'days': days, if (q != null && q.isNotEmpty) 'q': q},
    );
    return (r.data as List).map((e) => PlatformVenue.fromJson(e)).toList();
  }

  Future<PlatformVenue> platformVenue(int id, {int days = 30}) async {
    final r = await _dio.get(
      '/api/v1/platform/restaurants/$id',
      queryParameters: {'days': days},
    );
    return PlatformVenue.fromJson(r.data as Map<String, dynamic>);
  }
}

final adminRepositoryProvider = Provider(
  (ref) => AdminRepository(ref.watch(dioProvider)),
);

final adminRestaurantsProvider = FutureProvider<List<Restaurant>>(
  (ref) => ref.watch(adminRepositoryProvider).restaurants(),
);

final stopListProvider = FutureProvider.family<List<MenuItem>, int>(
  (ref, restaurantId) =>
      ref.watch(adminRepositoryProvider).stopList(restaurantId),
);

final adminRestaurantProvider = FutureProvider.family<Restaurant, int>(
  (ref, id) => ref.watch(adminRepositoryProvider).restaurant(id),
);

final platformOverviewProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(adminRepositoryProvider).overview(),
);

final restaurantWorkspaceProvider =
    FutureProvider.family<Map<String, dynamic>, int>(
      (ref, id) => ref.watch(adminRepositoryProvider).workspace(id),
    );

class PlatformQuery {
  const PlatformQuery({this.q = '', this.days = 30});

  final String q;
  final int days;

  @override
  bool operator ==(Object other) =>
      other is PlatformQuery && other.q == q && other.days == days;

  @override
  int get hashCode => Object.hash(q, days);
}

final platformVenuesProvider =
    FutureProvider.family<List<PlatformVenue>, PlatformQuery>(
      (ref, query) => ref
          .watch(adminRepositoryProvider)
          .platformVenues(q: query.q, days: query.days),
    );

final platformVenueProvider = FutureProvider.family<PlatformVenue, int>(
  (ref, id) => ref.watch(adminRepositoryProvider).platformVenue(id),
);
