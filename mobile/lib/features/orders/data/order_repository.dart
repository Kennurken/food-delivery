import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../cart/presentation/cart_controller.dart';
import '../domain/order.dart';

class OrderRepository {
  OrderRepository(this._dio);

  final Dio _dio;

  Future<Order> create({
    required CartState cart,
    required String address,
    String? comment,
  }) async {
    final r = await _dio.post('/api/v1/orders', data: {
      'restaurant_id': cart.restaurantId,
      'address': address,
      'comment': comment,
      'items': [
        for (final i in cart.items.values) {'menu_item_id': i.item.id, 'quantity': i.quantity},
      ],
    });
    return Order.fromJson(r.data);
  }

  Future<List<Order>> list() async {
    final r = await _dio.get('/api/v1/orders');
    return (r.data as List).map((e) => Order.fromJson(e)).toList();
  }

  Future<Order> get(int id) async {
    final r = await _dio.get('/api/v1/orders/$id');
    return Order.fromJson(r.data);
  }

  Future<Order> cancel(int id) async {
    final r = await _dio.post('/api/v1/orders/$id/cancel');
    return Order.fromJson(r.data);
  }

  // --- admin
  Future<Order> setStatus(int id, OrderStatus status) async {
    final r = await _dio.patch('/api/v1/orders/$id/status', data: {'status': status.wire});
    return Order.fromJson(r.data);
  }

  // --- courier
  Future<List<Order>> available() async {
    final r = await _dio.get('/api/v1/orders/available');
    return (r.data as List).map((e) => Order.fromJson(e)).toList();
  }

  Future<Order> accept(int id) async {
    final r = await _dio.post('/api/v1/orders/$id/accept');
    return Order.fromJson(r.data);
  }

  Future<Order> advance(int id) async {
    final r = await _dio.post('/api/v1/orders/$id/advance');
    return Order.fromJson(r.data);
  }
}

final orderRepositoryProvider = Provider((ref) => OrderRepository(ref.watch(dioProvider)));

final ordersProvider = FutureProvider<List<Order>>((ref) {
  // Auto-refresh while the list is on screen; disposed when nobody watches it.
  final timer = Timer(const Duration(seconds: 10), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(orderRepositoryProvider).list();
});

final orderProvider = FutureProvider.family<Order, int>(
  (ref, id) => ref.watch(orderRepositoryProvider).get(id),
);

/// Re-fetches order every [interval] while status is not final.
/// Cheap stand-in for push notifications until FCM lands.
final orderPollingProvider = StreamProvider.family<Order, int>((ref, id) async* {
  final repo = ref.watch(orderRepositoryProvider);
  const interval = Duration(seconds: 4);
  while (true) {
    final order = await repo.get(id);
    yield order;
    if (order.status.isFinal) return;
    await Future<void>.delayed(interval);
  }
});

final availableOrdersProvider = FutureProvider<List<Order>>(
  (ref) => ref.watch(orderRepositoryProvider).available(),
);
