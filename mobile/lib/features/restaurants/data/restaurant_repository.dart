import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../map/presentation/map_origin.dart';
import '../../reservations/domain/floor_table.dart';
import '../domain/promo_quote.dart';
import '../domain/delivery_quote.dart';
import '../domain/restaurant.dart';
import '../domain/sort.dart';

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

  Future<List<FloorTable>> tables(int restaurantId) async {
    final r = await _dio.get('/api/v1/restaurants/$restaurantId/tables');
    return [
      for (final row in r.data as List)
        FloorTable.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<List<String>> cuisines() async {
    final r = await _dio.get('/api/v1/restaurants/cuisines');
    return (r.data as List).cast<String>();
  }

  Future<Restaurant> get(int id) async {
    final r = await _dio.get('/api/v1/restaurants/$id');
    return Restaurant.fromJson(r.data);
  }

  Future<PromoQuote> quotePromo({
    required int restaurantId,
    required String code,
    required double subtotal,
  }) async {
    final r = await _dio.get(
      '/api/v1/restaurants/$restaurantId/promo',
      queryParameters: {'code': code, 'subtotal': subtotal},
    );
    return PromoQuote.fromJson(r.data as Map<String, dynamic>);
  }

  Future<DeliveryQuote> deliveryQuote(
    int restaurantId, {
    double? lat,
    double? lng,
    String? address,
  }) async {
    final r = await _dio.get(
      '/api/v1/restaurants/$restaurantId/delivery-quote',
      queryParameters: {
        'lat': ?lat,
        'lng': ?lng,
        if (address != null && address.isNotEmpty) 'address': address,
      },
    );
    return DeliveryQuote.fromJson(r.data as Map<String, dynamic>);
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
  void clear() => state = null;
}

final cuisineFilterProvider = NotifierProvider<CuisineFilter, String?>(
  CuisineFilter.new,
);

class RestaurantSortCtrl extends Notifier<RestaurantSort> {
  @override
  RestaurantSort build() => RestaurantSort.rating;

  void set(RestaurantSort value) => state = value;
}

final restaurantSortProvider =
    NotifierProvider<RestaurantSortCtrl, RestaurantSort>(
      RestaurantSortCtrl.new,
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

final sortedRestaurantsProvider = Provider<AsyncValue<List<Restaurant>>>((ref) {
  final sort = ref.watch(restaurantSortProvider);
  final origin = ref.watch(mapOriginProvider);
  return ref
      .watch(restaurantsProvider)
      .whenData((list) => sortRestaurants(list, sort, origin: origin));
});

final restaurantProvider = FutureProvider.family<Restaurant, int>(
  (ref, id) => ref.watch(restaurantRepositoryProvider).get(id),
);

final restaurantTablesProvider = FutureProvider.family<List<FloorTable>, int>(
  (ref, id) => ref.watch(restaurantRepositoryProvider).tables(id),
);

/// Where the basket is going. Re-quoting on every keystroke would hammer the
/// geocoder, so the cart only asks once it has a point or a settled address.
class DeliveryTarget {
  const DeliveryTarget({
    required this.restaurantId,
    this.lat,
    this.lng,
    this.address,
  });

  final int restaurantId;
  final double? lat;
  final double? lng;
  final String? address;

  bool get hasTarget =>
      (lat != null && lng != null) ||
      (address != null && address!.trim().length >= 3);

  @override
  bool operator ==(Object other) =>
      other is DeliveryTarget &&
      other.restaurantId == restaurantId &&
      other.lat == lat &&
      other.lng == lng &&
      other.address == address;

  @override
  int get hashCode => Object.hash(restaurantId, lat, lng, address);
}

final deliveryQuoteProvider =
    FutureProvider.family<DeliveryQuote, DeliveryTarget>((ref, target) {
      return ref
          .watch(restaurantRepositoryProvider)
          .deliveryQuote(
            target.restaurantId,
            lat: target.lat,
            lng: target.lng,
            address: target.address,
          );
    });
