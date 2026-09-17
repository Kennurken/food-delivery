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
}

final orderRepositoryProvider = Provider((ref) => OrderRepository(ref.watch(dioProvider)));

final ordersProvider = FutureProvider<List<Order>>(
  (ref) => ref.watch(orderRepositoryProvider).list(),
);

final orderProvider = FutureProvider.family<Order, int>(
  (ref, id) => ref.watch(orderRepositoryProvider).get(id),
);
