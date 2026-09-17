class MenuItem {
  const MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.isAvailable,
    this.imageUrl,
  });

  final int id;
  final int restaurantId;
  final String name;
  final String description;
  final double price;
  final String category;
  final String? imageUrl;
  final bool isAvailable;

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
        id: json['id'] as int,
        restaurantId: json['restaurant_id'] as int,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        category: json['category'] as String,
        imageUrl: json['image_url'] as String?,
        isAvailable: json['is_available'] as bool,
      );
}
