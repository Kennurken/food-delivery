/// A city the service delivers in. The slug is what the API filters by.
class City {
  const City({required this.slug, required this.name, this.lat, this.lng});

  final String slug;
  final String name;
  final double? lat;
  final double? lng;

  factory City.fromJson(Map<String, dynamic> json) => City(
    slug: json['slug'] as String,
    name: json['name'] as String,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
  );
}
