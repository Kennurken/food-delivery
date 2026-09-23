import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/venue_stats.dart';

class StatsRepository {
  StatsRepository(this._dio);

  final Dio _dio;

  Future<VenueStats> venue(int restaurantId, {int days = 30}) async {
    final r = await _dio.get(
      '/api/v1/admin/restaurants/$restaurantId/stats',
      queryParameters: {'days': days},
    );
    return VenueStats.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<List<VenueCustomer>> customers(
    int restaurantId, {
    int days = 90,
  }) async {
    final r = await _dio.get(
      '/api/v1/admin/restaurants/$restaurantId/customers',
      queryParameters: {'days': days},
    );
    final rows = (r.data as Map)['customers'] as List? ?? const [];
    return rows
        .map((e) => VenueCustomer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<PlatformRevenue> platform({int days = 30}) async {
    final r = await _dio.get(
      '/api/v1/platform/revenue',
      queryParameters: {'days': days},
    );
    return PlatformRevenue.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(ref.watch(dioProvider)),
);

/// Which venue the stats tab is looking at. Riverpod 3: a Notifier, never
/// StateProvider.
class StatsVenue extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final statsVenueProvider = NotifierProvider<StatsVenue, int?>(StatsVenue.new);

class StatsWindow extends Notifier<int> {
  @override
  int build() => 30;

  void set(int days) => state = days;
}

final statsWindowProvider = NotifierProvider<StatsWindow, int>(StatsWindow.new);

final venueStatsProvider = FutureProvider.family<VenueStats, int>(
  (ref, restaurantId) => ref
      .watch(statsRepositoryProvider)
      .venue(restaurantId, days: ref.watch(statsWindowProvider)),
);

final venueCustomersProvider = FutureProvider.family<List<VenueCustomer>, int>(
  (ref, restaurantId) => ref
      .watch(statsRepositoryProvider)
      .customers(restaurantId, days: ref.watch(statsWindowProvider)),
);

final platformRevenueProvider = FutureProvider<PlatformRevenue>(
  (ref) => ref
      .watch(statsRepositoryProvider)
      .platform(days: ref.watch(statsWindowProvider)),
);
