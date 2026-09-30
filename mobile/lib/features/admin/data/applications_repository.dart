import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/application.dart';

/// The platform's review of restaurants that applied to join.
class ApplicationsRepository {
  ApplicationsRepository(this._dio);

  final Dio _dio;

  Future<List<Application>> pending() async {
    final r = await _dio.get('/api/v1/admin/applications');
    return [
      for (final row in r.data as List)
        Application.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<void> decide(
    int restaurantId, {
    required bool approve,
    String? reason,
  }) {
    return _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/approval',
      data: {
        'approve': approve,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }
}

final applicationsRepositoryProvider = Provider<ApplicationsRepository>(
  (ref) => ApplicationsRepository(ref.watch(dioProvider)),
);

final pendingApplicationsProvider =
    FutureProvider.autoDispose<List<Application>>(
      (ref) => ref.watch(applicationsRepositoryProvider).pending(),
    );
