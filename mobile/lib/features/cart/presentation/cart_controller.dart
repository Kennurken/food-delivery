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

  /// keyed by [CartItem.key] (`menuItemId` or `menuItemId:sortedOptionIds`)
  final Map<String, CartItem> items;
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

  int quantityOf(int menuItemId) => items.values
      .where((i) => i.item.id == menuItemId)
      .fold(0, (s, i) => s + i.quantity);

  CartState copyWith({
    int? restaurantId,
    Map<String, CartItem>? items,
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
    final parsed = <String, CartItem>{};
    for (final value in raw.values) {
      final line = CartItem.fromJson(value as Map<String, dynamic>);
      final existing = parsed[line.key];
      parsed[line.key] = existing == null
          ? line
          : existing.copyWith(quantity: existing.quantity + line.quantity);
    }
    return CartState(
      restaurantId: json['restaurant_id'] as int?,
      qrToken: json['qr_token'] as String?,
      fulfillment: json['fulfillment'] as String? ?? 'delivery',
      destLat: coord(json['dest_lat']),
      destLng: coord(json['dest_lng']),
      destLine: json['dest_line'] as String?,
      items: parsed,
    );
  }

  Map<String, dynamic> toJson() => {
    'restaurant_id': restaurantId,
    'qr_token': qrToken,
    'fulfillment': fulfillment,
    'dest_lat': destLat,
    'dest_lng': destLng,
    'dest_line': destLine,
    'items': {for (final e in items.entries) e.key: e.value.toJson()},
  };
}

abstract class CartStore {
  Future<CartState?> read();
  Future<void> write(CartState state);
}

class CartStorage implements CartStore {
  CartStorage([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _key = 'cart_v2';
  static const _legacy = 'cart_v1';

  @override
  Future<CartState?> read() async {
    try {
      final raw =
          await _storage.read(key: _key) ?? await _storage.read(key: _legacy);
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
        await _storage.delete(key: _legacy);
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
  bool add(MenuItem item, {List<int>? optionIds, int quantity = 1}) {
    final other =
        state.restaurantId != null && state.restaurantId != item.restaurantId;
    if (other) return false;
    final ids = optionIds ?? item.defaultOptionIds;
    final key = CartItem.lineKey(item.id, ids);
    final existing = state.items[key];
    final next = Map<String, CartItem>.from(state.items)
      ..[key] =
          existing?.copyWith(quantity: existing.quantity + quantity) ??
          CartItem(item: item, quantity: quantity, optionIds: ids);
    state = state.copyWith(restaurantId: item.restaurantId, items: next);
    Haptics.add();
    _save();
    return true;
  }

  void remove(MenuItem item, {List<int>? optionIds}) {
    final key = optionIds != null
        ? CartItem.lineKey(item.id, optionIds)
        : state.items.entries
              .where((e) => e.value.item.id == item.id)
              .map((e) => e.key)
              .lastOrNull;
    if (key == null) return;
    removeLine(key, all: false);
  }

  void removeLine(String key, {bool all = true}) {
    final existing = state.items[key];
    if (existing == null) return;
    final next = Map<String, CartItem>.from(state.items);
    if (all || existing.quantity <= 1) {
      next.remove(key);
    } else {
      next[key] = existing.copyWith(quantity: existing.quantity - 1);
    }
    state = next.isEmpty ? const CartState() : state.copyWith(items: next);
    Haptics.tap();
    _save();
  }

  void removeAll(MenuItem item, {List<int>? optionIds}) {
    if (optionIds != null) {
      removeLine(CartItem.lineKey(item.id, optionIds));
      return;
    }
    final next = {
      for (final e in state.items.entries)
        if (e.value.item.id != item.id) e.key: e.value,
    };
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

  int quantityOf(int menuItemId) => state.quantityOf(menuItemId);

  /// Replace the cart with these lines (one restaurant). Empty list clears.
  void replaceAll(List<CartItem> items, {String fulfillment = 'delivery'}) {
    if (items.isEmpty) {
      clear();
      return;
    }
    final merged = <String, CartItem>{};
    for (final line in items) {
      final existing = merged[line.key];
      merged[line.key] = existing == null
          ? line
          : existing.copyWith(quantity: existing.quantity + line.quantity);
    }
    state = CartState(
      restaurantId: items.first.item.restaurantId,
      items: merged,
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
