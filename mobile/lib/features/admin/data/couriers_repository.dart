import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Someone a restaurant has hired to deliver its orders.
class VenueCourier {
  const VenueCourier({
    required this.userId,
    required this.email,
    required this.name,
  });

  final int userId;
  final String email;
  final String name;

  factory VenueCourier.fromJson(Map<String, dynamic> json) => VenueCourier(
    userId: (json['user_id'] as num).toInt(),
    email: json['email'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );
}

/// A venue's own couriers. They are staff with the `delivery_courier` role: the
/// server then shows them this venue's deliveries and nobody else's.
class CouriersRepository {
  CouriersRepository(this._dio);

  static const role = 'delivery_courier';

  final Dio _dio;

  Future<List<VenueCourier>> list(int restaurantId) async {
    final r = await _dio.get('/api/v1/admin/restaurants/$restaurantId/staff');
    return [
      for (final row in r.data as List)
        if ((row as Map)['role'] == role && row['is_active'] != false)
          VenueCourier.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> add(int restaurantId, String email) => _dio.post(
    '/api/v1/admin/restaurants/$restaurantId/staff',
    data: {'email': email.trim(), 'role': role},
  );

  Future<void> remove(int restaurantId, int userId) =>
      _dio.delete('/api/v1/admin/restaurants/$restaurantId/staff/$userId');
}

final couriersRepositoryProvider = Provider<CouriersRepository>(
  (ref) => CouriersRepository(ref.watch(dioProvider)),
);

final venueCouriersProvider = FutureProvider.autoDispose
    .family<List<VenueCourier>, int>(
      (ref, id) => ref.watch(couriersRepositoryProvider).list(id),
    );
