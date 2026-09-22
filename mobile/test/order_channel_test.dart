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
  test('every channel uses the same kitchen steps', () {
    expect(order().kitchenNext, [OrderStatus.onTheWay]);
    expect(order(channel: 'qr_table').kitchenNext, [OrderStatus.onTheWay]);
    expect(order(channel: 'pickup').kitchenNext, [OrderStatus.onTheWay]);
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

  test('dest and courier pins come from json', () {
    final o = Order.fromJson({
      'id': 1,
      'restaurant_id': 1,
      'restaurant_name': 'Bao',
      'status': 'on_the_way',
      'address': 'Abay 1',
      'subtotal': 1,
      'delivery_fee': 0,
      'total': 1,
      'created_at': '2026-01-01T00:00:00',
      'items': <dynamic>[],
      'rating': null,
      'customer': {'id': 1, 'name': 'A', 'phone': null},
      'courier': {'id': 2, 'name': 'C', 'phone': null},
      'dest_lat': 43.24,
      'dest_lng': 76.94,
      'pickup_lat': 43.25,
      'pickup_lng': 76.92,
      'courier_lat': 43.245,
      'courier_lng': 76.93,
    });
    expect(o.hasMap, isTrue);
    expect(o.destLat, 43.24);
    expect(o.courierLat, 43.245);
  });
}
