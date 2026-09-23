import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/courier_earnings.dart';

class EarningsRepository {
  EarningsRepository(this._dio);

  final Dio _dio;

  Future<CourierEarnings> fetch({int days = 7}) async {
    final r = await _dio.get(
      '/api/v1/me/earnings',
      queryParameters: {'days': days},
    );
    return CourierEarnings.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}

final earningsRepositoryProvider = Provider<EarningsRepository>(
  (ref) => EarningsRepository(ref.watch(dioProvider)),
);

/// The window the courier picked. Riverpod 3: a Notifier, never StateProvider.
class EarningsWindow extends Notifier<int> {
  @override
  int build() => 7;

  void set(int days) => state = days;
}

final earningsWindowProvider = NotifierProvider<EarningsWindow, int>(
  EarningsWindow.new,
);

final earningsProvider = FutureProvider<CourierEarnings>((ref) {
  final days = ref.watch(earningsWindowProvider);
  return ref.watch(earningsRepositoryProvider).fetch(days: days);
});
