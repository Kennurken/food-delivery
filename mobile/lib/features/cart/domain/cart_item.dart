import '../../restaurants/domain/menu_item.dart';

class CartItem {
  const CartItem({required this.item, required this.quantity});

  final MenuItem item;
  final int quantity;

  double get lineTotal => item.price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(item: item, quantity: quantity ?? this.quantity);

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    item: MenuItem.fromJson(json['item'] as Map<String, dynamic>),
    quantity: json['quantity'] as int,
  );

  Map<String, dynamic> toJson() => {
    'item': item.toJson(),
    'quantity': quantity,
  };
}
