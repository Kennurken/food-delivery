import 'menu_item.dart';

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
  );
}
