import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;

  Future<User> login(String email, String password) async {
    final r = await _dio.post(
      '/api/v1/auth/login/json',
      data: {'email': email, 'password': password},
    );
    return _saveToken(r.data);
  }

  /// A session for someone sitting at a table, in exchange for their scan.
  ///
  /// Asking a diner to register before they can order at a table they are
  /// already sitting at is how the order gets abandoned.
  Future<User> guest(String qrToken) async {
    final r = await _dio.post(
      '/api/v1/auth/guest',
      data: {'qr_token': qrToken},
    );
    return _saveToken(r.data);
  }

  Future<User> register({
    required String email,
    required String name,
    required String password,
    String? phone,
  }) async {
    final r = await _dio.post(
      '/api/v1/auth/register',
      data: {
        'email': email,
        'name': name,
        'password': password,
        'phone': phone,
      },
    );
    return _saveToken(r.data);
  }

  Future<User?> me() async {
    if (await _storage.read() == null && await _storage.readRefresh() == null) {
      return null;
    }
    try {
      final r = await _dio.get('/api/v1/auth/me');
      return User.fromJson(r.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _storage.clear();
        return null;
      }
      rethrow;
    }
  }

  Future<void> logout() => _storage.clear();

  Future<User> _saveToken(Map<String, dynamic> data) async {
    await _storage.write(
      data['access_token'] as String,
      refresh: data['refresh_token'] as String?,
    );
    return User.fromJson(data['user']);
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      AuthRepository(ref.watch(dioProvider), ref.watch(tokenStorageProvider)),
);
