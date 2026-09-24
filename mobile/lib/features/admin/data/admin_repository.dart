import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../restaurants/domain/menu_item.dart';
import '../../restaurants/domain/restaurant.dart';
import '../domain/platform_venue.dart';

class AdminRepository {
  AdminRepository(this._dio);

  final Dio _dio;

  Future<List<Restaurant>> restaurants() async {
    final r = await _dio.get('/api/v1/admin/restaurants');
    return (r.data as List).map((e) => Restaurant.fromJson(e)).toList();
  }

  Future<Restaurant> restaurant(int id) async {
    final r = await _dio.get('/api/v1/admin/restaurants/$id');
    return Restaurant.fromJson(r.data);
  }

  Future<Restaurant> createRestaurant(Map<String, dynamic> data) async {
    final r = await _dio.post('/api/v1/admin/restaurants', data: data);
    return Restaurant.fromJson(r.data);
  }

  Future<Restaurant> updateRestaurant(
    int id,
    Map<String, dynamic> patch,
  ) async {
    final r = await _dio.patch('/api/v1/admin/restaurants/$id', data: patch);
    return Restaurant.fromJson(r.data);
  }

  Future<MenuItem> updateMenuItem(int id, Map<String, dynamic> patch) async {
    final r = await _dio.patch('/api/v1/admin/menu/$id', data: patch);
    return MenuItem.fromJson(r.data);
  }

  Future<VenueSettings> venueSettings(int restaurantId) async {
    final r = await _dio.get(
      '/api/v1/admin/restaurants/$restaurantId/features',
    );
    return VenueSettings.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<void> setFeature(
    int restaurantId,
    String key, {
    required bool enabled,
  }) => _dio.put(
    '/api/v1/admin/restaurants/$restaurantId/features',
    data: {'key': key, 'enabled': enabled},
  );

  /// Drop the override so the flag follows the plan again.
  Future<void> clearFeature(int restaurantId, String key) =>
      _dio.delete('/api/v1/admin/restaurants/$restaurantId/features/$key');

  Future<void> setPlan(int restaurantId, String planCode) => _dio.patch(
    '/api/v1/admin/restaurants/$restaurantId',
    data: {'plan_code': planCode},
  );

  Future<VenueBilling> billing(int restaurantId) async {
    final r = await _dio.get('/api/v1/admin/restaurants/$restaurantId/billing');
    return VenueBilling.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  /// Opens Stripe Checkout. The plan does not move until the webhook lands —
  /// returning a URL is the whole of what this does.
  Future<String> subscribe(int restaurantId, String planCode) async {
    final r = await _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/billing/subscribe',
      data: {'plan_code': planCode},
    );
    return (r.data as Map)['checkout_url'] as String;
  }

  Future<VenueBilling> cancelSubscription(int restaurantId) async {
    final r = await _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/billing/cancel',
    );
    return VenueBilling.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<List<BillingPlan>> plans() async {
    final r = await _dio.get('/api/v1/billing/plans');
    return (r.data as List)
        .map((e) => BillingPlan.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  /// Campaigns of one venue, running or not — this is the editor's list.
  Future<List<Map<String, dynamic>>> offers(int restaurantId) async {
    final r = await _dio.get('/api/v1/admin/restaurants/$restaurantId/offers');
    return (r.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createOffer(
    int restaurantId,
    Map<String, dynamic> body,
  ) async {
    final r = await _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/offers',
      data: body,
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> updateOffer(
    int offerId,
    Map<String, dynamic> patch,
  ) async {
    final r = await _dio.patch('/api/v1/admin/offers/$offerId', data: patch);
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> deleteOffer(int offerId) =>
      _dio.delete('/api/v1/admin/offers/$offerId');

  /// Dishes currently off sale.
  Future<List<MenuItem>> stopList(int restaurantId) async {
    final r = await _dio.get(
      '/api/v1/admin/restaurants/$restaurantId/stop-list',
    );
    return (r.data as List).map((e) => MenuItem.fromJson(e)).toList();
  }

  /// Stop or restore several dishes in one call — bringing a menu back one
  /// dish at a time is how something stays off for a week.
  Future<void> setAvailability(
    int restaurantId,
    List<int> itemIds, {
    required bool available,
  }) async {
    if (itemIds.isEmpty) return;
    await _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/stop-list',
      data: {'item_ids': itemIds, 'available': available},
    );
  }

  Future<MenuItem> createMenuItem(
    int restaurantId,
    Map<String, dynamic> data,
  ) async {
    final r = await _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/menu',
      data: data,
    );
    return MenuItem.fromJson(r.data);
  }

  Future<void> deleteMenuItem(int id) => _dio.delete('/api/v1/admin/menu/$id');

  Future<MenuItem> replaceModifiers(
    int itemId,
    List<Map<String, dynamic>> groups,
  ) async {
    final r = await _dio.put(
      '/api/v1/admin/menu/$itemId/modifiers',
      data: groups,
    );
    return MenuItem.fromJson(r.data);
  }

  Future<Map<String, dynamic>> overview() async {
    final r = await _dio.get('/api/v1/platform/overview');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> workspace(int restaurantId) async {
    final r = await _dio.get(
      '/api/v1/admin/restaurants/$restaurantId/workspace',
    );
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> promos(int restaurantId) async {
    final r = await _dio.get('/api/v1/admin/restaurants/$restaurantId/promos');
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  Future<void> createPromo(int restaurantId, Map<String, dynamic> data) async {
    await _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/promos',
      data: data,
    );
  }

  Future<void> setPromoActive(int promoId, bool active) async {
    await _dio.patch(
      '/api/v1/admin/promos/$promoId',
      data: {'is_active': active},
    );
  }

  Future<List<Map<String, dynamic>>> reservations(int restaurantId) async {
    final r = await _dio.get(
      '/api/v1/admin/restaurants/$restaurantId/reservations',
    );
    return (r.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createReservation(
    int restaurantId,
    Map<String, dynamic> data,
  ) async {
    final r = await _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/reservations',
      data: data,
    );
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateReservation(
    int reservationId, {
    String? status,
    int? tableObjectId,
  }) async {
    final r = await _dio.patch(
      '/api/v1/admin/reservations/$reservationId',
      data: {'status': ?status, 'table_object_id': ?tableObjectId},
    );
    return r.data as Map<String, dynamic>;
  }

  // --- platform admin directory
  Future<List<PlatformVenue>> platformVenues({String? q, int days = 30}) async {
    final r = await _dio.get(
      '/api/v1/platform/restaurants',
      queryParameters: {'days': days, if (q != null && q.isNotEmpty) 'q': q},
    );
    return (r.data as List).map((e) => PlatformVenue.fromJson(e)).toList();
  }

  Future<PlatformVenue> platformVenue(int id, {int days = 30}) async {
    final r = await _dio.get(
      '/api/v1/platform/restaurants/$id',
      queryParameters: {'days': days},
    );
    return PlatformVenue.fromJson(r.data as Map<String, dynamic>);
  }
}

final adminRepositoryProvider = Provider(
  (ref) => AdminRepository(ref.watch(dioProvider)),
);

final adminRestaurantsProvider = FutureProvider<List<Restaurant>>(
  (ref) => ref.watch(adminRepositoryProvider).restaurants(),
);

final stopListProvider = FutureProvider.family<List<MenuItem>, int>(
  (ref, restaurantId) =>
      ref.watch(adminRepositoryProvider).stopList(restaurantId),
);

final adminRestaurantProvider = FutureProvider.family<Restaurant, int>(
  (ref, id) => ref.watch(adminRepositoryProvider).restaurant(id),
);

final platformOverviewProvider = FutureProvider<Map<String, dynamic>>(
  (ref) => ref.watch(adminRepositoryProvider).overview(),
);

final restaurantWorkspaceProvider =
    FutureProvider.family<Map<String, dynamic>, int>(
      (ref, id) => ref.watch(adminRepositoryProvider).workspace(id),
    );

class PlatformQuery {
  const PlatformQuery({this.q = '', this.days = 30});

  final String q;
  final int days;

  @override
  bool operator ==(Object other) =>
      other is PlatformQuery && other.q == q && other.days == days;

  @override
  int get hashCode => Object.hash(q, days);
}

final platformVenuesProvider =
    FutureProvider.family<List<PlatformVenue>, PlatformQuery>(
      (ref, query) => ref
          .watch(adminRepositoryProvider)
          .platformVenues(q: query.q, days: query.days),
    );

final platformVenueProvider = FutureProvider.family<PlatformVenue, int>(
  (ref, id) => ref.watch(adminRepositoryProvider).platformVenue(id),
);

/// One feature key for one venue: what the plan gives, what was forced, and
/// what is therefore in effect.
class VenueFeature {
  const VenueFeature({
    required this.key,
    required this.inPlan,
    required this.override,
    required this.enabled,
  });

  final String key;
  final bool inPlan;

  /// null = follows the plan. true/false = forced on or off for this venue.
  final bool? override;
  final bool enabled;

  factory VenueFeature.fromJson(Map<String, dynamic> json) => VenueFeature(
    key: json['key'] as String? ?? '',
    inPlan: json['in_plan'] as bool? ?? false,
    override: json['override'] as bool?,
    enabled: json['enabled'] as bool? ?? false,
  );
}

class VenueSettings {
  const VenueSettings({
    required this.planCode,
    required this.limits,
    required this.features,
  });

  final String planCode;
  final Map<String, int?> limits;
  final List<VenueFeature> features;

  factory VenueSettings.fromJson(Map<String, dynamic> json) {
    final rawLimits = (json['limits'] as Map?) ?? const {};
    return VenueSettings(
      planCode: json['plan_code'] as String? ?? '',
      limits: {
        for (final entry in rawLimits.entries)
          entry.key.toString(): (entry.value as num?)?.toInt(),
      },
      features: ((json['features'] as List?) ?? const [])
          .map(
            (e) => VenueFeature.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(growable: false),
    );
  }
}

final venueSettingsProvider = FutureProvider.family<VenueSettings, int>(
  (ref, id) => ref.watch(adminRepositoryProvider).venueSettings(id),
);

/// What a venue pays the platform, and where that stands.
class VenueBilling {
  const VenueBilling({
    required this.planCode,
    required this.planName,
    required this.monthlyPrice,
    required this.billed,
    required this.billingStatus,
    required this.renewsAt,
    required this.hasSubscription,
    required this.billingEnabled,
  });

  final String planCode;
  final String planName;
  final double monthlyPrice;
  final bool billed;
  final String billingStatus;
  final DateTime? renewsAt;
  final bool hasSubscription;

  /// False when the platform has no Stripe keys: subscribing would fail, so
  /// the screen says so rather than offering a button that cannot work.
  final bool billingEnabled;

  factory VenueBilling.fromJson(Map<String, dynamic> json) => VenueBilling(
    planCode: json['plan_code'] as String? ?? '',
    planName: json['plan_name'] as String? ?? '',
    monthlyPrice: (json['monthly_price'] as num?)?.toDouble() ?? 0,
    billed: json['billed'] as bool? ?? false,
    billingStatus: json['billing_status'] as String? ?? '',
    renewsAt: DateTime.tryParse(json['renews_at'] as String? ?? ''),
    hasSubscription: json['has_subscription'] as bool? ?? false,
    billingEnabled: json['billing_enabled'] as bool? ?? false,
  );

  /// Stripe is retrying the card. The venue keeps working — this is a warning,
  /// not a closure.
  bool get isRetrying => billingStatus == 'past_due';
  bool get isBlocked =>
      const {'suspended', 'cancelled', 'expired'}.contains(billingStatus);
}

class BillingPlan {
  const BillingPlan({
    required this.code,
    required this.name,
    required this.monthlyPrice,
    required this.billed,
  });

  final String code;
  final String name;
  final double monthlyPrice;
  final bool billed;

  factory BillingPlan.fromJson(Map<String, dynamic> json) => BillingPlan(
    code: json['code'] as String? ?? '',
    name: json['name'] as String? ?? '',
    monthlyPrice: (json['monthly_price'] as num?)?.toDouble() ?? 0,
    billed: json['billed'] as bool? ?? false,
  );
}

final venueBillingProvider = FutureProvider.family<VenueBilling, int>(
  (ref, id) => ref.watch(adminRepositoryProvider).billing(id),
);

final billingPlansProvider = FutureProvider<List<BillingPlan>>(
  (ref) => ref.watch(adminRepositoryProvider).plans(),
);
