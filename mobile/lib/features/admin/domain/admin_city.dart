/// A city as the platform admin sees it, switched-off ones included.
///
/// `slug` is its public address (/astana/) and never changes; `nameIn` is the
/// name as it reads after "в" ("Астане"), which Russian can't derive.
class AdminCity {
  const AdminCity({
    required this.id,
    required this.slug,
    required this.name,
    required this.nameIn,
    required this.lat,
    required this.lng,
    required this.utcOffsetMin,
    required this.isActive,
    required this.sortOrder,
    required this.venues,
  });

  final int id;
  final String slug;
  final String name;
  final String? nameIn;
  final double? lat;
  final double? lng;
  final int? utcOffsetMin;
  final bool isActive;
  final int sortOrder;
  final int venues;

  factory AdminCity.fromJson(Map<String, dynamic> json) => AdminCity(
    id: json['id'] as int,
    slug: json['slug'] as String,
    name: json['name'] as String,
    nameIn: json['name_in'] as String?,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
    utcOffsetMin: json['utc_offset_min'] as int?,
    isActive: json['is_active'] as bool? ?? false,
    sortOrder: json['sort_order'] as int? ?? 0,
    venues: json['venues'] as int? ?? 0,
  );
}
