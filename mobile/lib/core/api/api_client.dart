import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/token_storage.dart';
import 'api_config.dart';

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
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) {
        final data = e.response?.data;
        String message = e.message ?? 'Network error';
        if (data is Map && data['detail'] != null) {
          final detail = data['detail'];
          message = detail is String ? detail : (detail as List).first['msg'].toString();
        }
        handler.reject(
          DioException(
            requestOptions: e.requestOptions,
            response: e.response,
            error: ApiException(message, statusCode: e.response?.statusCode),
          ),
        );
      },
    ),
  );
  return dio;
});

/// Extract [ApiException] from any thrown error for display.
String errorMessage(Object e) {
  if (e is DioException && e.error is ApiException) return e.error.toString();
  return e.toString();
}
