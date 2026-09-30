import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/loyalty.dart';

class LoyaltyRepository {
  LoyaltyRepository(this._dio);

  final Dio _dio;

  /// Get a loyalty quote for [restaurantId] with the given [subtotal] (food total after promo).
  Future<LoyaltyQuote> quote(int restaurantId, {double? subtotal}) async {
    final query = <String, dynamic>{};
    if (subtotal != null) query['subtotal'] = subtotal;
    final r = await _dio.get(
      '/api/v1/me/loyalty/$restaurantId',
      queryParameters: query.isEmpty ? null : query,
    );
    return LoyaltyQuote.fromJson(r.data);
  }

  /// Get all loyalty balances for the current user (venues with positive balance only).
  Future<List<LoyaltyBalance>> mine() async {
    final r = await _dio.get('/api/v1/me/loyalty');
    return (r.data as List)
        .map((e) => LoyaltyBalance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Save or update the bonus programme for a venue.
  /// [percent] 0–30, [maxShare] 0–1 (fraction).
  Future<void> saveProgramme(
    int restaurantId, {
    required double percent,
    required double maxShare,
  }) async {
    await _dio.put(
      '/api/v1/admin/restaurants/$restaurantId/loyalty',
      data: {'percent': percent, 'max_share': maxShare},
    );
  }
}

final loyaltyRepositoryProvider = Provider(
  (ref) => LoyaltyRepository(ref.watch(dioProvider)),
);

/// Current user's loyalty balances across all venues (positive only).
final myBonusesProvider = FutureProvider<List<LoyaltyBalance>>((ref) {
  return ref.watch(loyaltyRepositoryProvider).mine();
});
