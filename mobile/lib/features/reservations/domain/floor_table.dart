class FloorTable {
  const FloorTable({
    required this.id,
    required this.name,
    required this.status,
    required this.floorName,
    required this.kind,
    this.capacity,
  });

  final int id;
  final String name;
  final int? capacity;
  final String status;
  final String floorName;
  final String kind;

  factory FloorTable.fromJson(Map<String, dynamic> json) => FloorTable(
    id: json['id'] as int,
    name: json['name'] as String,
    capacity: json['capacity'] as int?,
    status: json['status'] as String? ?? 'available',
    floorName: json['floor_name'] as String? ?? '',
    kind: json['kind'] as String? ?? 'table_round',
  );
}
