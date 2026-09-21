import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/haptics.dart';
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
      CartState(
        restaurantId: restaurantId ?? this.restaurantId,
        items: items ?? this.items,
      );

  factory CartState.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as Map<String, dynamic>? ?? {};
    return CartState(
      restaurantId: json['restaurant_id'] as int?,
      items: {
        for (final e in raw.entries)
          int.parse(e.key): CartItem.fromJson(e.value as Map<String, dynamic>),
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'restaurant_id': restaurantId,
    'items': {for (final e in items.entries) '${e.key}': e.value.toJson()},
  };
}

abstract class CartStore {
  Future<CartState?> read();
  Future<void> write(CartState state);
}

class CartStorage implements CartStore {
  CartStorage([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _key = 'cart_v1';

  @override
  Future<CartState?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      return CartState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(CartState state) async {
    try {
      if (state.isEmpty) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: jsonEncode(state.toJson()));
      }
    } catch (_) {}
  }
}

final cartStorageProvider = Provider<CartStore>((_) => CartStorage());

class CartController extends Notifier<CartState> {
  var _ready = false;

  @override
  CartState build() {
    unawaited(_hydrate());
    return const CartState();
  }

  Future<void> _hydrate() async {
    final saved = await ref.read(cartStorageProvider).read();
    if (!ref.mounted) return;
    if (saved != null && state.isEmpty) state = saved;
    _ready = true;
    _save();
  }

  void _save() {
    if (!_ready) return;
    unawaited(ref.read(cartStorageProvider).write(state));
  }

  /// Returns false if item belongs to another restaurant (cart must be cleared first).
  bool add(MenuItem item) {
    final other =
        state.restaurantId != null && state.restaurantId != item.restaurantId;
    if (other) return false;
    final existing = state.items[item.id];
    final next = Map<int, CartItem>.from(state.items)
      ..[item.id] =
          existing?.copyWith(quantity: existing.quantity + 1) ??
          CartItem(item: item, quantity: 1);
    state = state.copyWith(restaurantId: item.restaurantId, items: next);
    Haptics.add();
    _save();
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
    Haptics.tap();
    _save();
  }

  void removeAll(MenuItem item) {
    final next = Map<int, CartItem>.from(state.items)..remove(item.id);
    state = next.isEmpty ? const CartState() : state.copyWith(items: next);
    _save();
  }

  void clear() {
    state = const CartState();
    _save();
  }

  int quantityOf(int menuItemId) => state.items[menuItemId]?.quantity ?? 0;
}

final cartProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);
