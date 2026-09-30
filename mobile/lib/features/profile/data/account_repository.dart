import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/meta.dart';

/// The account itself, as opposed to what is in it: its password, its
/// deletion, and the platform's legal and support details around it.
class AccountRepository {
  AccountRepository(this._dio);

  final Dio _dio;

  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    await _dio.post(
      '/api/v1/me/password',
      data: {'current_password': current, 'new_password': next},
    );
  }

  /// The server anonymises the account; the session is useless afterwards,
  /// so the caller logs out. Refused with a readable 409 while the user owns a
  /// venue or has an order in progress.
  Future<void> deleteAccount(String password) async {
    await _dio.delete('/api/v1/me', data: {'password': password});
  }

  Future<Meta> meta() async {
    final r = await _dio.get('/api/v1/meta');
    return Meta.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}

final accountRepositoryProvider = Provider(
  (ref) => AccountRepository(ref.watch(dioProvider)),
);

/// Kept for the whole session: login, register and profile all read it, and
/// the platform's contacts do not change while the app is open.
final metaProvider = FutureProvider<Meta>(
  (ref) => ref.watch(accountRepositoryProvider).meta(),
);
