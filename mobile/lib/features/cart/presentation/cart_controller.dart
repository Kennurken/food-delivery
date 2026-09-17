import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../restaurants/domain/menu_item.dart';
import '../domain/cart_item.dart';

class CartState {
  const CartState({this.restaurantId, this.items = const {}});

  final int? restaurantId;

  /// keyed by menu item id
  final Map<int, CartItem> items;

  int get count => items.values.fold(0, (s, i) => s + i.quantity);
  double get subtotal => items.values.fold(0.0, (s, i) => s + i.lineTotal);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({int? restaurantId, Map<int, CartItem>? items}) =>
      CartState(restaurantId: restaurantId ?? this.restaurantId, items: items ?? this.items);
}

class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Returns false if item belongs to another restaurant (cart must be cleared first).
  bool add(MenuItem item) {
    if (state.restaurantId != null && state.restaurantId != item.restaurantId) return false;
    final existing = state.items[item.id];
    final next = Map<int, CartItem>.from(state.items)
      ..[item.id] = existing?.copyWith(quantity: existing.quantity + 1) ?? CartItem(item: item, quantity: 1);
    state = state.copyWith(restaurantId: item.restaurantId, items: next);
    return true;
  }

  void remove(MenuItem item) {
    final existing = state.items[item.id];
    if (existing == null) return;
    final next = Map<int, CartItem>.from(state.items);
    if (existing.quantity <= 1) {
      next.remove(item.id);
    } else {
      next[item.id] = existing.copyWith(quantity: existing.quantity - 1);
    }
    state = next.isEmpty ? const CartState() : state.copyWith(items: next);
  }

  void clear() => state = const CartState();

  int quantityOf(int menuItemId) => state.items[menuItemId]?.quantity ?? 0;
}

final cartProvider = NotifierProvider<CartController, CartState>(CartController.new);
