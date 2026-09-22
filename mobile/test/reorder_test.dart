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

  test('keeps modifiers when they still exist', () {
    final size = const ModifierGroup(
      id: 1,
      name: 'Size',
      required: true,
      minSelect: 1,
      maxSelect: 1,
      options: [
        ModifierOption(
          id: 10,
          name: 'Regular',
          priceDelta: 0,
          isDefault: true,
          isAvailable: true,
        ),
        ModifierOption(
          id: 11,
          name: 'Large',
          priceDelta: 400,
          isDefault: false,
          isAvailable: true,
        ),
      ],
    );
    final bao = MenuItem(
      id: 1,
      restaurantId: 10,
      name: 'Bao',
      description: '',
      price: 1500,
      category: 'Buns',
      isAvailable: true,
      groups: [size],
    );
    final plan = planReorder(
      ordered: [
        OrderItem(
          menuItemId: 1,
          name: 'Bao',
          price: 1900,
          quantity: 1,
          modifiers: const [OrderModifier(optionId: 11, name: 'Large')],
        ),
      ],
      menu: [bao],
    );
    expect(plan.items.single.optionIds, [11]);
    expect(plan.items.single.unitPrice, 1900);
  });

  test('falls back to defaults when old option is gone', () {
    final size = const ModifierGroup(
      id: 1,
      name: 'Size',
      required: true,
      minSelect: 1,
      maxSelect: 1,
      options: [
        ModifierOption(
          id: 10,
          name: 'Regular',
          priceDelta: 0,
          isDefault: true,
          isAvailable: true,
        ),
      ],
    );
    final bao = MenuItem(
      id: 1,
      restaurantId: 10,
      name: 'Bao',
      description: '',
      price: 1500,
      category: 'Buns',
      isAvailable: true,
      groups: [size],
    );
    final plan = planReorder(
      ordered: [
        OrderItem(
          menuItemId: 1,
          name: 'Bao',
          price: 1900,
          quantity: 1,
          modifiers: const [OrderModifier(optionId: 99, name: 'Gone')],
        ),
      ],
      menu: [bao],
    );
    expect(plan.items.single.optionIds, [10]);
  });
}
