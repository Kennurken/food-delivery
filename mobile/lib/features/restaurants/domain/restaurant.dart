import 'menu_item.dart';
import 'opening_hours.dart';

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.description,
    required this.cuisine,
    required this.rating,
    required this.ratingCount,
    required this.deliveryFee,
    required this.deliveryTimeMin,
    required this.isOpen,
    this.acceptingOrders = true,
    this.kitchenBusy = false,
    this.imageUrl,
    this.menu = const [],
    this.planCode,
    this.channels = const ['delivery'],
    this.reservations = false,
    this.lat,
    this.lng,
    this.citySlug,
    this.cityName,
    this.openNow = true,
    this.opensAt,
    this.loyaltyPercent = 0,
    this.loyaltyMaxShare = 0.5,
    this.hours = const [],
    this.approval = 'approved',
    this.offersDelivery = true,
  });

  final int id;
  final String name;
  final String description;
  final String cuisine;
  final String? imageUrl;
  final double rating;
  final int ratingCount;
  final double deliveryFee;
  final int deliveryTimeMin;
  final bool isOpen;

  /// Open with room on the stove. A busy kitchen is still 'open' — the owner
  /// did not close it — but it cannot take another ticket right now.
  final bool acceptingOrders;
  final bool kitchenBusy;
  final String? planCode;
  final List<String> channels;
  final bool reservations;
  final List<MenuItem> menu;
  final double? lat;
  final double? lng;
  final String? citySlug;
  final String? cityName;

  /// By the venue's opening hours. `acceptingOrders` already folds it in;
  /// this says *why* a venue isn't taking orders.
  final bool openNow;

  /// When closed by the schedule: the next opening on the venue's own wall
  /// clock. Deliberately not converted to the phone's zone — "opens at 10:00"
  /// means ten where the kitchen is, even for someone browsing from Astana
  /// with a phone still on another zone.
  final DateTime? opensAt;

  /// Share of paid food returned as bonuses; 0 = no programme.
  final double loyaltyPercent;

  /// Largest share (0–1) of an order's food that bonuses may pay.
  final double loyaltyMaxShare;

  /// The week, when the API sent it (the venue detail does; lists don't).
  final List<OpeningStretch> hours;

  /// pending | approved | rejected. Guests only ever get approved venues; an
  /// owner sees their own whatever it is.
  final String approval;
  final bool offersDelivery;

  bool get isPending => approval == 'pending';
  bool get isRejected => approval == 'rejected';

  bool get hasPin =>
      lat != null &&
      lng != null &&
      lat!.abs() <= 90 &&
      lng!.abs() <= 180 &&
      !(lat == 0 && lng == 0);

  bool get allowsDelivery => channels.contains('delivery');
  bool get allowsPickup => channels.contains('pickup');
  bool get allowsTable => channels.contains('qr_table');
  bool get allowsReservations => reservations;

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    cuisine: json['cuisine'] as String,
    imageUrl: json['image_url'] as String?,
    rating: (json['rating'] as num).toDouble(),
    ratingCount: json['rating_count'] as int? ?? 0,
    deliveryFee: (json['delivery_fee'] as num).toDouble(),
    deliveryTimeMin: json['delivery_time_min'] as int,
    isOpen: json['is_open'] as bool,
    acceptingOrders: json['accepting_orders'] as bool? ?? true,
    kitchenBusy: json['kitchen_busy'] as bool? ?? false,
    planCode: json['plan_code'] as String?,
    channels: [
      for (final c in json['channels'] as List<dynamic>? ?? ['delivery'])
        c as String,
    ],
    reservations: json['reservations'] as bool? ?? false,
    menu: (json['menu_items'] as List<dynamic>? ?? [])
        .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    lat: json['lat'] is num ? (json['lat'] as num).toDouble() : null,
    lng: json['lng'] is num ? (json['lng'] as num).toDouble() : null,
    citySlug: json['city_slug'] as String?,
    cityName: json['city_name'] as String?,
    openNow: json['open_now'] as bool? ?? true,
    opensAt: wallClock(json['opens_at'] as String?),
    loyaltyPercent: (json['loyalty_percent'] as num?)?.toDouble() ?? 0,
    approval: json['approval'] as String? ?? 'approved',
    offersDelivery: json['offers_delivery'] as bool? ?? true,
    loyaltyMaxShare: (json['loyalty_max_share'] as num?)?.toDouble() ?? 0.5,
    hours: [
      for (final h in json['hours'] as List<dynamic>? ?? const [])
        OpeningStretch.fromJson(h as Map<String, dynamic>),
    ],
  );

  /// "2026-10-01T10:00:00+05:00" → 10:00 on 1 Oct, as written. DateTime.parse
  /// would shift it to UTC and the venue's "10:00" would print as "05:00".
  static DateTime? wallClock(String? iso) {
    if (iso == null || iso.length < 19) return null;
    return DateTime.tryParse(iso.substring(0, 19));
  }
}
