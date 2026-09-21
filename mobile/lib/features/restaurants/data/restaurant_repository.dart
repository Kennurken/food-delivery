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

final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) {
  final q = ref.watch(restaurantSearchProvider);
  return ref.watch(restaurantRepositoryProvider).list(query: q);
});

final restaurantProvider = FutureProvider.family<Restaurant, int>(
  (ref, id) => ref.watch(restaurantRepositoryProvider).get(id),
);
