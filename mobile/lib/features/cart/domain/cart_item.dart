import '../../restaurants/domain/menu_item.dart';

class CartItem {
  const CartItem({required this.item, required this.quantity});

  final MenuItem item;
  final int quantity;

  double get lineTotal => item.price * quantity;

  CartItem copyWith({int? quantity}) => CartItem(item: item, quantity: quantity ?? this.quantity);
}
