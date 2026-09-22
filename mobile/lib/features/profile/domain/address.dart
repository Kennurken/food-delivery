String formatAddress(
  String line, {
  String? apt,
  String? entrance,
  String? floor,
  String? intercom,
  String aptLabel = 'apt',
  String entranceLabel = 'ent.',
  String floorLabel = 'fl.',
  String intercomLabel = 'intercom',
}) {
  final parts = <String>[line.trim()];
  void add(String? value, String label) {
    final v = value?.trim();
    if (v != null && v.isNotEmpty) parts.add('$label $v');
  }

  add(apt, aptLabel);
  add(entrance, entranceLabel);
  add(floor, floorLabel);
  add(intercom, intercomLabel);
  return parts.join(', ');
}

class AddressDraft {
  const AddressDraft({
    required this.label,
    required this.line,
    this.apt,
    this.entrance,
    this.floor,
    this.intercom,
    this.lat,
    this.lng,
  });

  final String label;
  final String line;
  final String? apt;
  final String? entrance;
  final String? floor;
  final String? intercom;
  final double? lat;
  final double? lng;
}

class Address {
  const Address({
    required this.id,
    required this.label,
    required this.line,
    this.apt,
    this.entrance,
    this.floor,
    this.intercom,
    this.lat,
    this.lng,
    required this.isDefault,
  });

  final int id;
  final String label;
  final String line;
  final String? apt;
  final String? entrance;
  final String? floor;
  final String? intercom;
  final double? lat;
  final double? lng;
  final bool isDefault;

  bool get hasPin =>
      lat != null &&
      lng != null &&
      lat!.abs() <= 90 &&
      lng!.abs() <= 180 &&
      !(lat == 0 && lng == 0);

  factory Address.fromJson(Map<String, dynamic> json) {
    String? opt(String key) {
      final v = json[key];
      if (v is! String) return null;
      final s = v.trim();
      return s.isEmpty ? null : s;
    }

    return Address(
      id: json['id'] as int,
      label: json['label'] as String,
      line: json['line'] as String,
      apt: opt('apt'),
      entrance: opt('entrance'),
      floor: opt('floor'),
      intercom: opt('intercom'),
      lat: json['lat'] is num ? (json['lat'] as num).toDouble() : null,
      lng: json['lng'] is num ? (json['lng'] as num).toDouble() : null,
      isDefault: json['is_default'] as bool,
    );
  }
}
