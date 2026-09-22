import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/reservation.dart';

class ReservationRepository {
  ReservationRepository(this._dio);

  final Dio _dio;

  Future<List<Reservation>> mine() async {
    final r = await _dio.get('/api/v1/reservations');
    return [
      for (final row in r.data as List)
        Reservation.fromJson(row as Map<String, dynamic>),
    ];
  }

  Future<Reservation> create({
    required int restaurantId,
    required String name,
    required DateTime startsAt,
    int guests = 2,
    String? phone,
    int? tableObjectId,
    int durationMin = 90,
    String? comment,
  }) async {
    final r = await _dio.post(
      '/api/v1/reservations',
      data: {
        'restaurant_id': restaurantId,
        'name': name,
        'guests': guests,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'duration_min': durationMin,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'table_object_id': ?tableObjectId,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    return Reservation.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Reservation> cancel(int id) async {
    final r = await _dio.post('/api/v1/reservations/$id/cancel');
    return Reservation.fromJson(r.data as Map<String, dynamic>);
  }
}

final reservationRepositoryProvider = Provider(
  (ref) => ReservationRepository(ref.watch(dioProvider)),
);

final myReservationsProvider = FutureProvider<List<Reservation>>(
  (ref) => ref.watch(reservationRepositoryProvider).mine(),
);
