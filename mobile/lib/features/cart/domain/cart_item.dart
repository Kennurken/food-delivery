import '../../restaurants/domain/menu_item.dart';

class CartItem {
  const CartItem({
    required this.item,
    required this.quantity,
    this.optionIds = const [],
  });

  final MenuItem item;
  final int quantity;
  final List<int> optionIds;

  static String lineKey(int menuItemId, Iterable<int> optionIds) {
    final ids = optionIds.toList()..sort();
    return ids.isEmpty ? '$menuItemId' : '$menuItemId:${ids.join(',')}';
  }

  String get key => lineKey(item.id, optionIds);

  double get unitPrice => item.priceWith(optionIds);

  double get lineTotal => unitPrice * quantity;

  String get extrasLabel => item.optionNames(optionIds).join(', ');

  CartItem copyWith({int? quantity, List<int>? optionIds}) => CartItem(
    item: item,
    quantity: quantity ?? this.quantity,
    optionIds: optionIds ?? this.optionIds,
  );

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    item: MenuItem.fromJson(json['item'] as Map<String, dynamic>),
    quantity: json['quantity'] as int,
    optionIds: [
      for (final id in json['option_ids'] as List<dynamic>? ?? []) id as int,
    ],
  );

  Map<String, dynamic> toJson() => {
    'item': item.toJson(),
    'quantity': quantity,
    'option_ids': optionIds,
  };
}
