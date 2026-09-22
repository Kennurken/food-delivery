import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/orders/domain/order.dart';

Order order({
  OrderStatus status = OrderStatus.preparing,
  String channel = 'delivery',
}) => Order(
  id: 1,
  restaurantId: 1,
  restaurantName: 'Bao',
  status: status,
  address: 'T12',
  subtotal: 1000,
  deliveryFee: 0,
  total: 1000,
  createdAt: DateTime(2026, 1, 1),
  items: const [],
  customer: const UserBrief(id: 1, name: 'A'),
  channel: channel,
);

void main() {
  test('delivery preparing hands to courier', () {
    expect(order().kitchenNext, [OrderStatus.onTheWay]);
  });

  test('table order preparing is served, not dispatched', () {
    expect(order(channel: 'qr_table').kitchenNext, [OrderStatus.delivered]);
  });

  test('legacy json without channel is delivery', () {
    final o = Order.fromJson({
      'id': 1,
      'restaurant_id': 1,
      'restaurant_name': 'Bao',
      'status': 'pending',
      'address': 'Abay 1',
      'subtotal': 1,
      'delivery_fee': 0,
      'total': 1,
      'created_at': '2026-01-01T00:00:00',
      'items': <dynamic>[],
      'rating': null,
      'customer': {'id': 1, 'name': 'A', 'phone': null},
      'courier': null,
    });
    expect(o.isDelivery, isTrue);
    expect(o.channel, 'delivery');
  });
}
