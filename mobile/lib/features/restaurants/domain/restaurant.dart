import 'menu_item.dart';

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.description,
    required this.cuisine,
    required this.rating,
    required this.deliveryFee,
    required this.deliveryTimeMin,
    required this.isOpen,
    this.imageUrl,
    this.menu = const [],
  });

  final int id;
  final String name;
  final String description;
  final String cuisine;
  final String? imageUrl;
  final double rating;
  final double deliveryFee;
  final int deliveryTimeMin;
  final bool isOpen;
  final List<MenuItem> menu;

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
    id: json['id'] as int,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    cuisine: json['cuisine'] as String,
    imageUrl: json['image_url'] as String?,
    rating: (json['rating'] as num).toDouble(),
    deliveryFee: (json['delivery_fee'] as num).toDouble(),
    deliveryTimeMin: json['delivery_time_min'] as int,
    isOpen: json['is_open'] as bool,
    menu: (json['menu_items'] as List<dynamic>? ?? [])
        .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
