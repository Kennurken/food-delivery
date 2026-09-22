class OrderModifier {
  const OrderModifier({
    required this.optionId,
    required this.name,
    this.group = '',
    this.price = 0,
  });

  final int optionId;
  final String name;
  final String group;
  final double price;

  factory OrderModifier.fromJson(Map<String, dynamic> json) => OrderModifier(
    optionId: json['option_id'] as int? ?? 0,
    name: json['name'] as String? ?? '',
    group: json['group'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
  );
}

class OrderItem {
  const OrderItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.modifiers = const [],
  });

  final int menuItemId;
  final String name;
  final double price;
  final int quantity;
  final List<OrderModifier> modifiers;

  List<int> get optionIds => [for (final m in modifiers) m.optionId];

  String get extrasLabel =>
      [for (final m in modifiers) m.name].where((n) => n.isNotEmpty).join(', ');

  String get ticketLine {
    final extras = extrasLabel;
    return extras.isEmpty ? '$quantity× $name' : '$quantity× $name ($extras)';
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    menuItemId: json['menu_item_id'] as int? ?? 0,
    name: json['name'] as String,
    price: (json['price'] as num).toDouble(),
    quantity: json['quantity'] as int,
    modifiers: [
      for (final m in json['modifiers'] as List<dynamic>? ?? [])
        OrderModifier.fromJson(m as Map<String, dynamic>),
    ],
  );
}

class UserBrief {
  const UserBrief({required this.id, required this.name, this.phone});

  final int id;
  final String name;
  final String? phone;

  factory UserBrief.fromJson(Map<String, dynamic> json) => UserBrief(
    id: json['id'] as int,
    name: json['name'] as String,
    phone: json['phone'] as String?,
  );
}

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  onTheWay('on_the_way'),
  delivered,
  cancelled;

  const OrderStatus([this._wire]);
  final String? _wire;

  String get wire => _wire ?? name;

  static OrderStatus parse(String s) =>
      values.firstWhere((v) => v.wire == s, orElse: () => pending);

  bool get canCancel => this == pending || this == confirmed;

  /// Admin transitions (mirrors backend state machine).
  List<OrderStatus> get adminNext => switch (this) {
    pending => [confirmed, cancelled],
    confirmed => [preparing, cancelled],
    preparing => [onTheWay],
    onTheWay => [delivered],
    _ => [],
  };
  bool get isFinal => this == delivered || this == cancelled;

  bool get canReorder => isFinal;

  /// Next step a courier can push this order to, or null.
  OrderStatus? get courierNext => switch (this) {
    confirmed => preparing,
    preparing => onTheWay,
    onTheWay => delivered,
    _ => null,
  };
}

class Order {
  const Order({
    required this.id,
    required this.restaurantId,
    required this.status,
    required this.address,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.createdAt,
    required this.items,
    required this.customer,
    required this.restaurantName,
    this.comment,
    this.courier,
    this.rating,
    this.channel = 'delivery',
    this.tableObjectId,
    this.destLat,
    this.destLng,
    this.pickupLat,
    this.pickupLng,
    this.courierLat,
    this.courierLng,
    this.courierHeading,
    this.courierSeenAt,
    this.payMethod = 'cash',
    this.payStatus = 'unpaid',
  });

  final int id;
  final int restaurantId;
  final String restaurantName;
  final int? rating;
  final UserBrief customer;
  final UserBrief? courier;
  final OrderStatus status;
  final String address;
  final String? comment;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String channel;
  final int? tableObjectId;
  final double? destLat;
  final double? destLng;
  final double? pickupLat;
  final double? pickupLng;
  final double? courierLat;
  final double? courierLng;
  final double? courierHeading;
  final DateTime? courierSeenAt;
  final String payMethod;
  final String payStatus;

  bool get isCash => payMethod == 'cash';
  bool get isPaid => payStatus == 'paid';

  bool get isDelivery => channel == 'delivery';
  bool get isPickup => channel == 'pickup';
  bool get isDineIn => channel == 'qr_table';
  bool get hasMap => destLat != null || pickupLat != null || courierLat != null;

  List<OrderStatus> get kitchenNext => status.adminNext;

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as int,
    restaurantId: json['restaurant_id'] as int,
    restaurantName: json['restaurant_name'] as String,
    customer: UserBrief.fromJson(json['customer']),
    courier: json['courier'] == null
        ? null
        : UserBrief.fromJson(json['courier']),
    status: OrderStatus.parse(json['status'] as String),
    address: json['address'] as String,
    comment: json['comment'] as String?,
    subtotal: (json['subtotal'] as num).toDouble(),
    deliveryFee: (json['delivery_fee'] as num).toDouble(),
    total: (json['total'] as num).toDouble(),
    createdAt: DateTime.parse(json['created_at'] as String),
    items: (json['items'] as List).map((e) => OrderItem.fromJson(e)).toList(),
    rating: json['rating'] as int?,
    channel: json['channel'] as String? ?? 'delivery',
    tableObjectId: json['table_object_id'] as int?,
    destLat: _coord(json['dest_lat']),
    destLng: _coord(json['dest_lng']),
    pickupLat: _coord(json['pickup_lat']),
    pickupLng: _coord(json['pickup_lng']),
    courierLat: _coord(json['courier_lat']),
    courierLng: _coord(json['courier_lng']),
    courierHeading: _coord(json['courier_heading']),
    courierSeenAt: json['courier_seen_at'] == null
        ? null
        : DateTime.tryParse(json['courier_seen_at'] as String),
    payMethod: json['pay_method'] as String? ?? 'cash',
    payStatus: json['pay_status'] as String? ?? 'unpaid',
  );
}

double? _coord(dynamic value) => value is num ? value.toDouble() : null;
