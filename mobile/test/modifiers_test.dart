import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/restaurants/domain/menu_item.dart';

MenuItem bao() => const MenuItem(
  id: 1,
  restaurantId: 1,
  name: 'Pork Bao',
  description: '',
  price: 1500,
  category: 'Buns',
  isAvailable: true,
  groups: [
    ModifierGroup(
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
    ),
    ModifierGroup(
      id: 2,
      name: 'Extras',
      required: false,
      minSelect: 0,
      maxSelect: 3,
      options: [
        ModifierOption(
          id: 20,
          name: 'Egg',
          priceDelta: 200,
          isDefault: false,
          isAvailable: true,
        ),
      ],
    ),
  ],
);

void main() {
  test('defaults are Regular only', () {
    expect(bao().defaultOptionIds, [10]);
    expect(bao().accepts([10]), isTrue);
    expect(bao().accepts([]), isFalse);
    expect(bao().accepts([11, 20]), isTrue);
    expect(bao().accepts([10, 11]), isFalse);
    expect(bao().priceWith([11, 20]), 2100);
  });

  test('line key sorts option ids', () {
    expect('${bao().id}:${([20, 11]..sort()).join(',')}', '1:11,20');
  });
}
