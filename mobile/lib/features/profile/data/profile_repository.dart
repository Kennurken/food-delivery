import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/domain/user.dart';
import '../domain/address.dart';

class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  /// Venues this person works at. Staff and owners are ordinary accounts with
  /// a membership, so this list is the only thing that makes them staff here.
  Future<List<VenueMembership>> memberships() async {
    final r = await _dio.get('/api/v1/me/memberships');
    return [
      for (final row in r.data as List)
        if ((row as Map)['is_active'] != false)
          VenueMembership.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<User> update({String? name, String? phone}) async {
    final r = await _dio.patch(
      '/api/v1/me',
      data: {'name': ?name, 'phone': ?phone},
    );
    return User.fromJson(r.data);
  }

  Future<List<Address>> addresses() async {
    final r = await _dio.get('/api/v1/me/addresses');
    return (r.data as List).map((e) => Address.fromJson(e)).toList();
  }

  Future<Address> addAddress(
    String label,
    String line, {
    String? apt,
    String? entrance,
    String? floor,
    String? intercom,
    double? lat,
    double? lng,
    bool isDefault = false,
  }) async {
    final r = await _dio.post(
      '/api/v1/me/addresses',
      data: {
        'label': label,
        'line': line,
        'is_default': isDefault,
        'apt': ?apt,
        'entrance': ?entrance,
        'floor': ?floor,
        'intercom': ?intercom,
        'lat': ?lat,
        'lng': ?lng,
      },
    );
    return Address.fromJson(r.data);
  }

  Future<void> deleteAddress(int id) => _dio.delete('/api/v1/me/addresses/$id');

  /// Pin a point onto an address that was only ever text.
  Future<Address> setPoint(
    int id, {
    required double lat,
    required double lng,
    String? line,
  }) async {
    final r = await _dio.patch(
      '/api/v1/me/addresses/$id',
      data: {'lat': lat, 'lng': lng, 'line': ?line},
    );
    return Address.fromJson(r.data);
  }

  Future<Address> setDefault(int id) async {
    final r = await _dio.patch(
      '/api/v1/me/addresses/$id',
      data: {'is_default': true},
    );
    return Address.fromJson(r.data);
  }
}

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(ref.watch(dioProvider)),
);

final addressesProvider = FutureProvider.autoDispose<List<Address>>(
  (ref) => ref.watch(profileRepositoryProvider).addresses(),
);

class VenueMembership {
  const VenueMembership({
    required this.restaurantId,
    required this.name,
    required this.role,
  });

  final int restaurantId;
  final String name;
  final String role;

  factory VenueMembership.fromJson(Map<String, dynamic> json) =>
      VenueMembership(
        restaurantId: (json['restaurant_id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? '',
      );
}

final myVenuesProvider = FutureProvider.autoDispose<List<VenueMembership>>(
  (ref) => ref.watch(profileRepositoryProvider).memberships(),
);
