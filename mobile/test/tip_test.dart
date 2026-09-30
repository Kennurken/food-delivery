import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/cart/presentation/cart_controller.dart';
import 'package:food_delivery/features/orders/data/order_repository.dart';
import 'package:food_delivery/features/orders/domain/order.dart';

const _orderJson = {
  'id': 1,
  'restaurant_id': 1,
  'restaurant_name': 'Bao',
  'status': 'pending',
  'address': 'Abay 1',
  'subtotal': 2000,
  'delivery_fee': 500,
  'total': 2700,
  'created_at': '2026-01-01T00:00:00',
  'items': <dynamic>[],
  'rating': null,
  'customer': {'id': 1, 'name': 'A', 'phone': null},
  'courier': null,
};

void main() {
  group('what the cart charges', () {
    test('a tip is part of the total on delivery', () {
      const cart = CartState(restaurantId: 1, tip: 500);

      expect(cart.payable(400), 900);
      expect(cart.effectiveTip, 500);
    });

    test('a table or a counter has no courier, so no tip', () {
      const pickup = CartState(
        restaurantId: 1,
        fulfillment: 'pickup',
        tip: 500,
      );
      const table = CartState(restaurantId: 1, qrToken: 'abc', tip: 500);

      expect(pickup.payable(0), 0);
      expect(pickup.effectiveTip, 0);
      expect(table.effectiveTip, 0);
    });

    test('the choice survives a restart', () {
      final back = CartState.fromJson(
        const CartState(restaurantId: 1, tip: 200).toJson(),
      );

      expect(back.tip, 200);
    });
  });

  group('the order request', () {
    Future<Map<String, dynamic>> bodyFor(CartState cart) async {
      Map<String, dynamic>? sent;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              sent = options.data as Map<String, dynamic>;
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: _orderJson,
                  statusCode: 200,
                ),
              );
            },
          ),
        );
      await OrderRepository(dio).create(cart: cart, address: 'Abay 1');
      return sent!;
    }

    test('sends the tip only when there is one to send', () async {
      expect(
        (await bodyFor(const CartState(restaurantId: 1))).containsKey('tip'),
        isFalse,
      );
      expect(
        (await bodyFor(const CartState(restaurantId: 1, tip: 500)))['tip'],
        500,
      );
    });

    test('never sends a tip the server would refuse', () async {
      final body = await bodyFor(
        const CartState(restaurantId: 1, fulfillment: 'pickup', tip: 500),
      );

      expect(body.containsKey('tip'), isFalse);
    });
  });

  test('an order reads its tip, and older servers mean none', () {
    expect(Order.fromJson({..._orderJson, 'tip': 700}).tip, 700);
    expect(Order.fromJson(_orderJson).tip, 0);
  });
}
