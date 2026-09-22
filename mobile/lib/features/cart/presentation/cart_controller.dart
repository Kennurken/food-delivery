import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/haptics.dart';
import '../../restaurants/domain/menu_item.dart';
import '../domain/cart_item.dart';

class CartState {
  const CartState({
    this.restaurantId,
    this.items = const {},
    this.qrToken,
    this.fulfillment = 'delivery',
    this.destLat,
    this.destLng,
    this.destLine,
  });

  final int? restaurantId;

  /// keyed by menu item id
  final Map<int, CartItem> items;
  final String? qrToken;

  /// `delivery` or `pickup`. Ignored when [isDineIn].
  final String fulfillment;
  final double? destLat;
  final double? destLng;
  final String? destLine;

  int get count => items.values.fold(0, (s, i) => s + i.quantity);
  double get subtotal => items.values.fold(0.0, (s, i) => s + i.lineTotal);
  bool get isEmpty => items.isEmpty;
  bool get isDineIn => qrToken != null;
  bool get isPickup => !isDineIn && fulfillment == 'pickup';
  bool get hasDest => destLat != null && destLng != null;

  CartState copyWith({
    int? restaurantId,
    Map<int, CartItem>? items,
    String? qrToken,
    bool clearQr = false,
    String? fulfillment,
    double? destLat,
    double? destLng,
    String? destLine,
    bool clearDest = false,
  }) => CartState(
    restaurantId: restaurantId ?? this.restaurantId,
    items: items ?? this.items,
    qrToken: clearQr ? null : (qrToken ?? this.qrToken),
    fulfillment: fulfillment ?? this.fulfillment,
    destLat: clearDest ? null : (destLat ?? this.destLat),
    destLng: clearDest ? null : (destLng ?? this.destLng),
    destLine: clearDest ? null : (destLine ?? this.destLine),
  );

  factory CartState.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as Map<String, dynamic>? ?? {};
    double? coord(dynamic v) => v is num ? v.toDouble() : null;
    return CartState(
      restaurantId: json['restaurant_id'] as int?,
      qrToken: json['qr_token'] as String?,
      fulfillment: json['fulfillment'] as String? ?? 'delivery',
      destLat: coord(json['dest_lat']),
      destLng: coord(json['dest_lng']),
      destLine: json['dest_line'] as String?,
      items: {
        for (final e in raw.entries)
          int.parse(e.key): CartItem.fromJson(e.value as Map<String, dynamic>),
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'restaurant_id': restaurantId,
    'qr_token': qrToken,
    'fulfillment': fulfillment,
    'dest_lat': destLat,
    'dest_lng': destLng,
    'dest_line': destLine,
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

  void setQrToken(String? token) {
    state = CartState(
      restaurantId: state.restaurantId,
      items: state.items,
      qrToken: token,
      fulfillment: state.fulfillment,
      destLat: state.destLat,
      destLng: state.destLng,
      destLine: state.destLine,
    );
    _save();
  }

  void setFulfillment(String channel) {
    if (channel != 'pickup' && channel != 'delivery') return;
    if (state.fulfillment == channel) return;
    state = state.copyWith(fulfillment: channel);
    _save();
  }

  void setDestination({
    required double lat,
    required double lng,
    required String line,
  }) {
    state = state.copyWith(destLat: lat, destLng: lng, destLine: line);
    _save();
  }

  int quantityOf(int menuItemId) => state.items[menuItemId]?.quantity ?? 0;

  /// Replace the cart with these lines (one restaurant). Empty list clears.
  void replaceAll(List<CartItem> items, {String fulfillment = 'delivery'}) {
    if (items.isEmpty) {
      clear();
      return;
    }
    state = CartState(
      restaurantId: items.first.item.restaurantId,
      items: {for (final i in items) i.item.id: i},
      fulfillment: fulfillment == 'pickup' ? 'pickup' : 'delivery',
      destLat: state.destLat,
      destLng: state.destLng,
      destLine: state.destLine,
    );
    Haptics.add();
    _save();
  }
}

final cartProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);
