class OrderItem {
  const OrderItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  final String name;
  final double price;
  final int quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    name: json['name'] as String,
    price: (json['price'] as num).toDouble(),
    quantity: json['quantity'] as int,
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

  String get label => switch (this) {
    pending => 'Pending',
    confirmed => 'Confirmed',
    preparing => 'Preparing',
    onTheWay => 'On the way',
    delivered => 'Delivered',
    cancelled => 'Cancelled',
  };

  bool get canCancel => this == pending || this == confirmed;

  /// Button label for an action that moves an order *to* this status.
  String get actionLabel => switch (this) {
    confirmed => 'Confirm',
    preparing => 'Start preparing',
    onTheWay => 'Hand to courier',
    delivered => 'Mark delivered',
    cancelled => 'Cancel',
    pending => 'Pending',
  };

  /// Admin transitions (mirrors backend state machine).
  List<OrderStatus> get adminNext => switch (this) {
    pending => [confirmed, cancelled],
    confirmed => [preparing, cancelled],
    preparing => [onTheWay],
    onTheWay => [delivered],
    _ => [],
  };
  bool get isFinal => this == delivered || this == cancelled;

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
  );
}
