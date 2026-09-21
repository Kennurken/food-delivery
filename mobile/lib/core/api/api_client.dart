import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import 'api_config.dart';

/// Bumped when a refresh fails so [AuthController] can drop the session.
class AuthExpired extends Notifier<int> {
  @override
  int build() => 0;

  void fire() => state++;
}

final authExpiredProvider = NotifierProvider<AuthExpired, int>(AuthExpired.new);

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );
  final storage = ref.watch(tokenStorageProvider);

  // Bare client for the refresh call itself — no interceptors, no recursion.
  final refresher = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
  Future<String?>? inflight; // dedupe concurrent refreshes

  Future<String?> refreshAccess() {
    return inflight ??= () async {
      try {
        final rt = await storage.readRefresh();
        if (rt == null) return null;
        final r = await refresher.post(
          '/api/v1/auth/refresh',
          data: {'refresh_token': rt},
        );
        final access = r.data['access_token'] as String;
        await storage.write(access);
        return access;
      } catch (_) {
        await storage.clear();
        ref.read(authExpiredProvider.notifier).fire();
        return null;
      } finally {
        inflight = null;
      }
    }();
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) async {
        final isAuthPath = e.requestOptions.path.contains('/auth/');
        final retried = e.requestOptions.extra['retried'] == true;
        if (e.response?.statusCode == 401 && !isAuthPath && !retried) {
          final access = await refreshAccess();
          if (access != null) {
            final opts = e.requestOptions
              ..headers['Authorization'] = 'Bearer $access'
              ..extra['retried'] = true;
            try {
              return handler.resolve(await dio.fetch(opts));
            } on DioException catch (again) {
              return handler.reject(_wrap(again));
            }
          }
        }
        handler.reject(_wrap(e));
      },
    ),
  );
  return dio;
});

DioException _wrap(DioException e) {
  final data = e.response?.data;
  String message = e.message ?? 'Network error';
  if (data is Map && data['detail'] != null) {
    final detail = data['detail'];
    message = detail is String
        ? detail
        : (detail as List).first['msg'].toString();
  } else if (data is Map && data['error'] != null) {
    message = data['error'].toString(); // slowapi 429 body
  }
  return DioException(
    requestOptions: e.requestOptions,
    response: e.response,
    error: ApiException(message, statusCode: e.response?.statusCode),
  );
}

/// Extract [ApiException] from any thrown error for display.
String errorMessage(Object e) {
  if (e is DioException && e.error is ApiException) return e.error.toString();
  return e.toString();
}
