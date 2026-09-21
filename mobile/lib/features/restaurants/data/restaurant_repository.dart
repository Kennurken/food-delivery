import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/restaurant.dart';

class RestaurantRepository {
  RestaurantRepository(this._dio);

  final Dio _dio;

  Future<List<Restaurant>> list({String? query, String? cuisine}) async {
    final r = await _dio.get(
      '/api/v1/restaurants',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        'cuisine': ?cuisine,
      },
    );
    return (r.data as List).map((e) => Restaurant.fromJson(e)).toList();
  }

  Future<List<String>> cuisines() async {
    final r = await _dio.get('/api/v1/restaurants/cuisines');
    return (r.data as List).cast<String>();
  }

  Future<Restaurant> get(int id) async {
    final r = await _dio.get('/api/v1/restaurants/$id');
    return Restaurant.fromJson(r.data);
  }
}

final restaurantRepositoryProvider = Provider(
  (ref) => RestaurantRepository(ref.watch(dioProvider)),
);

class RestaurantSearch extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final restaurantSearchProvider = NotifierProvider<RestaurantSearch, String>(
  RestaurantSearch.new,
);

class CuisineFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void toggle(String cuisine) => state = state == cuisine ? null : cuisine;
}

final cuisineFilterProvider = NotifierProvider<CuisineFilter, String?>(
  CuisineFilter.new,
);

final cuisinesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(restaurantRepositoryProvider).cuisines(),
);

final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) {
  final q = ref.watch(restaurantSearchProvider);
  final cuisine = ref.watch(cuisineFilterProvider);
  return ref
      .watch(restaurantRepositoryProvider)
      .list(query: q, cuisine: cuisine);
});

final restaurantProvider = FutureProvider.family<Restaurant, int>(
  (ref, id) => ref.watch(restaurantRepositoryProvider).get(id),
);
