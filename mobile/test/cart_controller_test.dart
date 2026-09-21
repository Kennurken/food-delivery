import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/cart/presentation/cart_controller.dart';
import 'package:food_delivery/features/restaurants/domain/menu_item.dart';

MenuItem item(int id, int restaurantId, double price) => MenuItem(
  id: id,
  restaurantId: restaurantId,
  name: 'Item $id',
  description: '',
  price: price,
  category: 'Main',
  isAvailable: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // CartController fires haptics
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('adds and increments quantity', () {
    final cart = container.read(cartProvider.notifier);
    cart.add(item(1, 10, 100));
    cart.add(item(1, 10, 100));
    final state = container.read(cartProvider);
    expect(state.count, 2);
    expect(state.subtotal, 200);
    expect(state.restaurantId, 10);
  });

  test('rejects item from another restaurant', () {
    final cart = container.read(cartProvider.notifier);
    expect(cart.add(item(1, 10, 100)), isTrue);
    expect(cart.add(item(2, 20, 100)), isFalse);
    expect(container.read(cartProvider).count, 1);
  });

  test('remove clears restaurant when empty', () {
    final cart = container.read(cartProvider.notifier);
    cart.add(item(1, 10, 100));
    cart.remove(item(1, 10, 100));
    expect(container.read(cartProvider).isEmpty, isTrue);
    expect(container.read(cartProvider).restaurantId, isNull);
  });
}
