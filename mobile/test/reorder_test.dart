import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/orders/domain/order.dart';
import 'package:food_delivery/features/orders/domain/reorder.dart';
import 'package:food_delivery/features/restaurants/domain/menu_item.dart';

MenuItem dish(int id, {bool available = true, double price = 100}) => MenuItem(
  id: id,
  restaurantId: 10,
  name: 'Dish $id',
  description: '',
  price: price,
  category: 'Main',
  isAvailable: available,
);

OrderItem line(int id, {int qty = 1, double price = 90}) =>
    OrderItem(menuItemId: id, name: 'Old $id', price: price, quantity: qty);

void main() {
  test('delivered and cancelled can reorder', () {
    expect(OrderStatus.delivered.canReorder, isTrue);
    expect(OrderStatus.cancelled.canReorder, isTrue);
    expect(OrderStatus.pending.canReorder, isFalse);
    expect(OrderStatus.onTheWay.canReorder, isFalse);
  });

  test('uses live price and quantity from the ticket', () {
    final plan = planReorder(
      ordered: [line(1, qty: 3, price: 50)],
      menu: [dish(1, price: 120)],
    );
    expect(plan.items, hasLength(1));
    expect(plan.items.single.quantity, 3);
    expect(plan.items.single.item.price, 120);
    expect(plan.skipped, 0);
  });

  test('skips missing and unavailable dishes', () {
    final plan = planReorder(
      ordered: [line(1), line(2), line(99)],
      menu: [dish(1), dish(2, available: false)],
    );
    expect(plan.items.single.item.id, 1);
    expect(plan.skipped, 2);
    expect(
      planReorder(
        ordered: [line(2)],
        menu: [dish(2, available: false)],
      ).isEmpty,
      isTrue,
    );
  });
}
