import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/orders/domain/order.dart';

void main() {
  test('customer can cancel only pending and confirmed', () {
    expect(OrderStatus.pending.canCancel, isTrue);
    expect(OrderStatus.confirmed.canCancel, isTrue);
    expect(OrderStatus.preparing.canCancel, isFalse);
    expect(OrderStatus.delivered.canCancel, isFalse);
  });

  test('admin next statuses match the backend machine', () {
    expect(OrderStatus.pending.adminNext, [
      OrderStatus.confirmed,
      OrderStatus.cancelled,
    ]);
    expect(OrderStatus.confirmed.adminNext, [
      OrderStatus.preparing,
      OrderStatus.cancelled,
    ]);
    expect(OrderStatus.preparing.adminNext, [OrderStatus.onTheWay]);
    expect(OrderStatus.onTheWay.adminNext, [OrderStatus.delivered]);
    expect(OrderStatus.delivered.adminNext, isEmpty);
    expect(OrderStatus.cancelled.adminNext, isEmpty);
  });

  test('courier advances preparing → on_the_way → delivered', () {
    expect(OrderStatus.preparing.courierNext, OrderStatus.onTheWay);
    expect(OrderStatus.onTheWay.courierNext, OrderStatus.delivered);
    expect(OrderStatus.pending.courierNext, isNull);
    expect(OrderStatus.delivered.courierNext, isNull);
  });

  test('only the kitchen starts cooking, never the courier', () {
    expect(OrderStatus.confirmed.courierNext, isNull);
  });

  test('parse maps wire values including on_the_way', () {
    expect(OrderStatus.parse('on_the_way'), OrderStatus.onTheWay);
    expect(OrderStatus.parse('pending'), OrderStatus.pending);
    expect(OrderStatus.parse('nope'), OrderStatus.pending);
  });
}
