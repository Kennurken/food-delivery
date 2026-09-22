import 'kinds.dart';

export 'kinds.dart';

class LayoutRect {
  const LayoutRect(this.x, this.y, this.w, this.h);

  final double x;
  final double y;
  final double w;
  final double h;

  double get right => x + w;
  double get bottom => y + h;
  double get cx => x + w / 2;
  double get cy => y + h / 2;

  bool overlaps(LayoutRect o, {double inset = 0}) {
    return x + inset < o.right - inset &&
        right - inset > o.x + inset &&
        y + inset < o.bottom - inset &&
        bottom - inset > o.y + inset;
  }

  bool containsPoint(double px, double py) =>
      px >= x && px <= right && py >= y && py <= bottom;

  LayoutRect inflate(double d) =>
      LayoutRect(x - d, y - d, w + d * 2, h + d * 2);

  LayoutRect shifted(double dx, double dy) => LayoutRect(x + dx, y + dy, w, h);
}

class LayoutNode {
  LayoutNode({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.zoneId,
    this.name = '',
    this.rotation = 0,
    this.zIndex = 0,
    this.capacity,
    this.minGuests,
    this.maxGuests,
    this.status = TableStatus.available,
    this.mergeable = false,
    this.mergeGroup,
    this.extra = const {},
  });

  int id;
  int? zoneId;
  LayoutKind kind;
  String name;
  double x;
  double y;
  double width;
  double height;
  double rotation;
  int zIndex;
  int? capacity;
  int? minGuests;
  int? maxGuests;
  TableStatus status;
  bool mergeable;
  String? mergeGroup;
  Map<String, dynamic> extra;

  LayoutRect get rect => LayoutRect(x, y, width, height);

  LayoutNode copy() => LayoutNode(
    id: id,
    zoneId: zoneId,
    kind: kind,
    name: name,
    x: x,
    y: y,
    width: width,
    height: height,
    rotation: rotation,
    zIndex: zIndex,
    capacity: capacity,
    minGuests: minGuests,
    maxGuests: maxGuests,
    status: status,
    mergeable: mergeable,
    mergeGroup: mergeGroup,
    extra: Map<String, dynamic>.from(extra),
  );

  factory LayoutNode.fromJson(Map<String, dynamic> json) => LayoutNode(
    id: json['id'] as int,
    zoneId: json['zone_id'] as int?,
    kind: layoutKindFromWire(json['kind'] as String),
    name: json['name'] as String? ?? '',
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    zIndex: json['z_index'] as int? ?? 0,
    capacity: json['capacity'] as int?,
    minGuests: json['min_guests'] as int?,
    maxGuests: json['max_guests'] as int?,
    status: tableStatusFromWire(json['status'] as String? ?? 'available'),
    mergeable: json['mergeable'] as bool? ?? false,
    mergeGroup: json['merge_group'] as String?,
    extra: Map<String, dynamic>.from(json['extra'] as Map? ?? const {}),
  );

  Map<String, dynamic> toJson() => {
    'id': id > 0 ? id : null,
    'zone_id': zoneId != null && zoneId! > 0 ? zoneId : null,
    'kind': kind.wire,
    'name': name,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
    'z_index': zIndex,
    'capacity': capacity,
    'min_guests': minGuests,
    'max_guests': maxGuests,
    'status': status.name,
    'mergeable': mergeable,
    'merge_group': mergeGroup,
    'extra': extra,
  };
}

class LayoutZone {
  LayoutZone({
    required this.id,
    required this.name,
    required this.kind,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.color = '#D9CDB8',
    this.capacity,
    this.description = '',
  });

  int id;
  String name;
  ZoneKind kind;
  String color;
  int? capacity;
  String description;
  double x;
  double y;
  double width;
  double height;

  LayoutRect get rect => LayoutRect(x, y, width, height);

  LayoutZone copy() => LayoutZone(
    id: id,
    name: name,
    kind: kind,
    color: color,
    capacity: capacity,
    description: description,
    x: x,
    y: y,
    width: width,
    height: height,
  );

  factory LayoutZone.fromJson(Map<String, dynamic> json) => LayoutZone(
    id: json['id'] as int,
    name: json['name'] as String,
    kind: zoneKindFromWire(json['kind'] as String? ?? 'hall'),
    color: json['color'] as String? ?? '#D9CDB8',
    capacity: json['capacity'] as int?,
    description: json['description'] as String? ?? '',
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id > 0 ? id : null,
    'name': name,
    'kind': kind.name,
    'color': color,
    'capacity': capacity,
    'description': description,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class FloorDoc {
  FloorDoc({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.sortOrder,
    required this.widthCm,
    required this.heightCm,
    required this.gridCm,
    required this.updatedAt,
    required this.zones,
    required this.objects,
  });

  int id;
  int restaurantId;
  String name;
  int sortOrder;
  double widthCm;
  double heightCm;
  int gridCm;
  String updatedAt;
  List<LayoutZone> zones;
  List<LayoutNode> objects;

  FloorDoc copy() => FloorDoc(
    id: id,
    restaurantId: restaurantId,
    name: name,
    sortOrder: sortOrder,
    widthCm: widthCm,
    heightCm: heightCm,
    gridCm: gridCm,
    updatedAt: updatedAt,
    zones: zones.map((z) => z.copy()).toList(),
    objects: objects.map((o) => o.copy()).toList(),
  );

  factory FloorDoc.fromJson(Map<String, dynamic> json) => FloorDoc(
    id: json['id'] as int,
    restaurantId: json['restaurant_id'] as int,
    name: json['name'] as String,
    sortOrder: json['sort_order'] as int? ?? 0,
    widthCm: (json['width_cm'] as num).toDouble(),
    heightCm: (json['height_cm'] as num).toDouble(),
    gridCm: json['grid_cm'] as int? ?? 40,
    updatedAt: json['updated_at'] as String,
    zones: (json['zones'] as List? ?? [])
        .map((e) => LayoutZone.fromJson(e as Map<String, dynamic>))
        .toList(),
    objects: (json['objects'] as List? ?? [])
        .map((e) => LayoutNode.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class FloorSummary {
  const FloorSummary({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final int sortOrder;
  final String updatedAt;

  factory FloorSummary.fromJson(Map<String, dynamic> json) => FloorSummary(
    id: json['id'] as int,
    name: json['name'] as String,
    sortOrder: json['sort_order'] as int? ?? 0,
    updatedAt: json['updated_at'] as String,
  );
}
