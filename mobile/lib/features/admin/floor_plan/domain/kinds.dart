enum LayoutKind {
  tableRound,
  tableSquare,
  tableRect,
  tableLarge,
  tableCustom,
  chair,
  sofa,
  booth,
  stool,
  reception,
  counter,
  wall,
  door,
  window,
  column,
  stairs,
  elevator,
  bar,
  kitchen,
  toilet,
  entrance,
  exit,
}

enum LayoutCategory { tables, furniture, structure, infra }

enum TableStatus { available, reserved, occupied, cleaning, disabled }

enum ZoneKind { hall, vip, terrace, bar, banquet, outdoor, smoking, private }

extension LayoutKindX on LayoutKind {
  String get wire => switch (this) {
    LayoutKind.tableRound => 'table_round',
    LayoutKind.tableSquare => 'table_square',
    LayoutKind.tableRect => 'table_rect',
    LayoutKind.tableLarge => 'table_large',
    LayoutKind.tableCustom => 'table_custom',
    LayoutKind.chair => 'chair',
    LayoutKind.sofa => 'sofa',
    LayoutKind.booth => 'booth',
    LayoutKind.stool => 'stool',
    LayoutKind.reception => 'reception',
    LayoutKind.counter => 'counter',
    LayoutKind.wall => 'wall',
    LayoutKind.door => 'door',
    LayoutKind.window => 'window',
    LayoutKind.column => 'column',
    LayoutKind.stairs => 'stairs',
    LayoutKind.elevator => 'elevator',
    LayoutKind.bar => 'bar',
    LayoutKind.kitchen => 'kitchen',
    LayoutKind.toilet => 'toilet',
    LayoutKind.entrance => 'entrance',
    LayoutKind.exit => 'exit',
  };

  LayoutCategory get category => switch (this) {
    LayoutKind.tableRound ||
    LayoutKind.tableSquare ||
    LayoutKind.tableRect ||
    LayoutKind.tableLarge ||
    LayoutKind.tableCustom => LayoutCategory.tables,
    LayoutKind.chair ||
    LayoutKind.sofa ||
    LayoutKind.booth ||
    LayoutKind.stool ||
    LayoutKind.reception ||
    LayoutKind.counter => LayoutCategory.furniture,
    LayoutKind.wall ||
    LayoutKind.door ||
    LayoutKind.window ||
    LayoutKind.column ||
    LayoutKind.stairs ||
    LayoutKind.elevator => LayoutCategory.structure,
    LayoutKind.bar ||
    LayoutKind.kitchen ||
    LayoutKind.toilet ||
    LayoutKind.entrance ||
    LayoutKind.exit => LayoutCategory.infra,
  };

  bool get isTable => category == LayoutCategory.tables;

  bool get isWallLike =>
      this == LayoutKind.wall ||
      this == LayoutKind.window ||
      this == LayoutKind.door;

  ({double w, double h}) get defaultSize => switch (this) {
    LayoutKind.tableRound => (w: 120, h: 120),
    LayoutKind.tableSquare => (w: 140, h: 140),
    LayoutKind.tableRect => (w: 200, h: 120),
    LayoutKind.tableLarge => (w: 240, h: 160),
    LayoutKind.tableCustom => (w: 160, h: 160),
    LayoutKind.chair => (w: 45, h: 45),
    LayoutKind.sofa => (w: 220, h: 90),
    LayoutKind.booth => (w: 180, h: 90),
    LayoutKind.stool => (w: 36, h: 36),
    LayoutKind.reception => (w: 220, h: 80),
    LayoutKind.counter => (w: 280, h: 70),
    LayoutKind.wall => (w: 400, h: 16),
    LayoutKind.door => (w: 120, h: 28),
    LayoutKind.window => (w: 160, h: 16),
    LayoutKind.column => (w: 40, h: 40),
    LayoutKind.stairs => (w: 140, h: 220),
    LayoutKind.elevator => (w: 140, h: 140),
    LayoutKind.bar => (w: 420, h: 90),
    LayoutKind.kitchen => (w: 280, h: 220),
    LayoutKind.toilet => (w: 160, h: 140),
    LayoutKind.entrance => (w: 140, h: 40),
    LayoutKind.exit => (w: 140, h: 40),
  };

  int? get defaultCapacity => switch (this) {
    LayoutKind.tableRound || LayoutKind.tableSquare => 4,
    LayoutKind.tableRect => 6,
    LayoutKind.tableLarge => 8,
    LayoutKind.tableCustom => 4,
    _ => null,
  };

  String get label => switch (this) {
    LayoutKind.tableRound => 'Round table',
    LayoutKind.tableSquare => 'Square table',
    LayoutKind.tableRect => 'Rectangle table',
    LayoutKind.tableLarge => 'Large table',
    LayoutKind.tableCustom => 'Custom table',
    LayoutKind.chair => 'Chair',
    LayoutKind.sofa => 'Sofa',
    LayoutKind.booth => 'Booth',
    LayoutKind.stool => 'Bar stool',
    LayoutKind.reception => 'Reception',
    LayoutKind.counter => 'Counter',
    LayoutKind.wall => 'Wall',
    LayoutKind.door => 'Door',
    LayoutKind.window => 'Window',
    LayoutKind.column => 'Column',
    LayoutKind.stairs => 'Stairs',
    LayoutKind.elevator => 'Elevator',
    LayoutKind.bar => 'Bar',
    LayoutKind.kitchen => 'Kitchen',
    LayoutKind.toilet => 'Toilet',
    LayoutKind.entrance => 'Entrance',
    LayoutKind.exit => 'Exit',
  };
}

extension ZoneKindX on ZoneKind {
  String get label => switch (this) {
    ZoneKind.hall => 'Main Hall',
    ZoneKind.vip => 'VIP',
    ZoneKind.terrace => 'Terrace',
    ZoneKind.bar => 'Bar',
    ZoneKind.banquet => 'Banquet',
    ZoneKind.outdoor => 'Outdoor',
    ZoneKind.smoking => 'Smoking Area',
    ZoneKind.private => 'Private Room',
  };

  String get tint => switch (this) {
    ZoneKind.hall => '#D9CDB8',
    ZoneKind.vip => '#CDB59A',
    ZoneKind.terrace => '#C5D0B8',
    ZoneKind.bar => '#C9B29A',
    ZoneKind.banquet => '#D4C4A8',
    ZoneKind.outdoor => '#B9CDB8',
    ZoneKind.smoking => '#C8C0B4',
    ZoneKind.private => '#C9B8C4',
  };
}

extension TableStatusX on TableStatus {
  String get label => switch (this) {
    TableStatus.available => 'Available',
    TableStatus.reserved => 'Reserved',
    TableStatus.occupied => 'Occupied',
    TableStatus.cleaning => 'Cleaning',
    TableStatus.disabled => 'Disabled',
  };
}

LayoutKind layoutKindFromWire(String value) {
  for (final k in LayoutKind.values) {
    if (k.wire == value) return k;
  }
  return LayoutKind.tableCustom;
}

TableStatus tableStatusFromWire(String value) {
  for (final s in TableStatus.values) {
    if (s.name == value) return s;
  }
  return TableStatus.available;
}

ZoneKind zoneKindFromWire(String value) {
  for (final k in ZoneKind.values) {
    if (k.name == value) return k;
  }
  return ZoneKind.hall;
}
