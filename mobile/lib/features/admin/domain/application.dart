/// A restaurant waiting for the platform's decision, with who to call.
class Application {
  const Application({
    required this.restaurantId,
    required this.name,
    required this.cuisine,
    required this.description,
    required this.hasCouriers,
    this.city,
    this.appliedAt,
    this.ownerName,
    this.ownerEmail,
    this.ownerPhone,
  });

  final int restaurantId;
  final String name;
  final String cuisine;
  final String description;
  final String? city;

  /// Its answer to "do you have your own couriers?". Without them it takes
  /// pickup and table orders only.
  final bool hasCouriers;
  final String? appliedAt;
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerPhone;

  factory Application.fromJson(Map<String, dynamic> json) => Application(
    restaurantId: json['restaurant_id'] as int,
    name: json['name'] as String? ?? '',
    cuisine: json['cuisine'] as String? ?? '',
    description: json['description'] as String? ?? '',
    city: json['city'] as String?,
    hasCouriers: json['has_couriers'] as bool? ?? true,
    appliedAt: json['applied_at'] as String?,
    ownerName: json['owner_name'] as String?,
    ownerEmail: json['owner_email'] as String?,
    ownerPhone: json['owner_phone'] as String?,
  );
}
