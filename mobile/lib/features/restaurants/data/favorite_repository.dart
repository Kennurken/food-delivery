import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/restaurant.dart';

class FavoriteRepository {
  FavoriteRepository(this._dio);

  final Dio _dio;

  Future<List<Restaurant>> list() async {
    final r = await _dio.get('/api/v1/me/favorites');
    return (r.data as List).map((e) => Restaurant.fromJson(e)).toList();
  }

  Future<void> add(int restaurantId) =>
      _dio.put('/api/v1/me/favorites/$restaurantId');

  Future<void> remove(int restaurantId) =>
      _dio.delete('/api/v1/me/favorites/$restaurantId');
}

final favoriteRepositoryProvider = Provider(
  (ref) => FavoriteRepository(ref.watch(dioProvider)),
);

class Favorites extends AsyncNotifier<List<Restaurant>> {
  @override
  Future<List<Restaurant>> build() async {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const [];
    return ref.read(favoriteRepositoryProvider).list();
  }

  Future<void> toggle(Restaurant restaurant) async {
    final repo = ref.read(favoriteRepositoryProvider);
    final current = [...(state.value ?? const <Restaurant>[])];
    final on = current.any((r) => r.id == restaurant.id);
    state = AsyncData(
      on
          ? current.where((r) => r.id != restaurant.id).toList()
          : [restaurant, ...current],
    );
    try {
      if (on) {
        await repo.remove(restaurant.id);
      } else {
        await repo.add(restaurant.id);
      }
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final favoritesProvider = AsyncNotifierProvider<Favorites, List<Restaurant>>(
  Favorites.new,
);
