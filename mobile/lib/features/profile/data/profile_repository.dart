import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/domain/user.dart';
import '../domain/address.dart';

class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<User> update({String? name, String? phone}) async {
    final r = await _dio.patch(
      '/api/v1/me',
      data: {'name': ?name, 'phone': ?phone},
    );
    return User.fromJson(r.data);
  }

  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    await _dio.post(
      '/api/v1/me/password',
      data: {'current_password': current, 'new_password': next},
    );
  }

  Future<List<Address>> addresses() async {
    final r = await _dio.get('/api/v1/me/addresses');
    return (r.data as List).map((e) => Address.fromJson(e)).toList();
  }

  Future<Address> addAddress(
    String label,
    String line, {
    bool isDefault = false,
  }) async {
    final r = await _dio.post(
      '/api/v1/me/addresses',
      data: {'label': label, 'line': line, 'is_default': isDefault},
    );
    return Address.fromJson(r.data);
  }

  Future<void> deleteAddress(int id) => _dio.delete('/api/v1/me/addresses/$id');

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
