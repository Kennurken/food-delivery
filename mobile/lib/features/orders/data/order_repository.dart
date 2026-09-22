import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/order_events.dart';
import '../../cart/presentation/cart_controller.dart';
import '../domain/order.dart';

class OrderRepository {
  OrderRepository(this._dio);

  final Dio _dio;

  Future<Order> create({
    required CartState cart,
    required String address,
    String? comment,
    String payMethod = 'cash',
  }) async {
    final r = await _dio.post(
      '/api/v1/orders',
      data: {
        'restaurant_id': cart.restaurantId,
        if (cart.qrToken != null) 'qr_token': cart.qrToken,
        if (cart.qrToken == null && cart.isPickup) 'channel': 'pickup',
        if (cart.qrToken == null && !cart.isPickup) 'address': address,
        if (cart.destLat != null) 'dest_lat': cart.destLat,
        if (cart.destLng != null) 'dest_lng': cart.destLng,
        'comment': comment,
        'pay_method': payMethod,
        'items': [
          for (final i in cart.items.values)
            {
              'menu_item_id': i.item.id,
              'quantity': i.quantity,
              'option_ids': i.optionIds,
            },
        ],
      },
    );
    return Order.fromJson(r.data);
  }

  Future<List<Order>> list({int? restaurantId}) async {
    final r = await _dio.get(
      '/api/v1/orders',
      queryParameters: {'restaurant_id': ?restaurantId},
    );
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

  Future<Order> rate(int id, int rating) async {
    final r = await _dio.post(
      '/api/v1/orders/$id/rate',
      data: {'rating': rating},
    );
    return Order.fromJson(r.data);
  }

  // --- admin
  Future<Order> setStatus(int id, OrderStatus status) async {
    final r = await _dio.patch(
      '/api/v1/orders/$id/status',
      data: {'status': status.wire},
    );
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

final orderRepositoryProvider = Provider(
  (ref) => OrderRepository(ref.watch(dioProvider)),
);

final ordersProvider = FutureProvider<List<Order>>((ref) {
  // Status / assignment changes the list. Location pings do not.
  ref.listen(orderEventsProvider, (_, next) {
    if (next.value?.isLocation ?? true) return;
    ref.invalidateSelf();
  });
  return ref.watch(orderRepositoryProvider).list();
});

final orderProvider = FutureProvider.family<Order, int>(
  (ref, id) => ref.watch(orderRepositoryProvider).get(id),
);

/// Initial fetch, then live updates for this order over WebSocket.
final orderLiveProvider = StreamProvider.family<Order, int>((ref, id) {
  final controller = StreamController<Order>();
  ref
      .watch(orderRepositoryProvider)
      .get(id)
      .then(controller.add, onError: controller.addError);
  ref.listen(orderEventsProvider, (_, next) {
    final evt = next.value;
    if (evt != null && evt.id == id && !controller.isClosed) {
      controller.add(Order.fromJson(evt.order));
    }
  });
  ref.onDispose(controller.close);
  return controller.stream;
});

final availableOrdersProvider = FutureProvider<List<Order>>((ref) {
  ref.listen(orderEventsProvider, (_, next) {
    if (next.value?.isLocation ?? true) return;
    ref.invalidateSelf();
  });
  return ref.watch(orderRepositoryProvider).available();
});

final kitchenOrdersProvider = FutureProvider.family<List<Order>, int>((
  ref,
  restaurantId,
) {
  ref.listen(orderEventsProvider, (_, next) {
    final evt = next.value;
    if (evt == null || evt.isLocation) return;
    if (evt.order['restaurant_id'] == restaurantId) {
      ref.invalidateSelf();
    }
  });
  return ref.watch(orderRepositoryProvider).list(restaurantId: restaurantId);
});
