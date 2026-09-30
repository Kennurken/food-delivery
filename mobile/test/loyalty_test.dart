import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/l10n/l10n.dart';
import 'package:food_delivery/features/admin/presentation/admin_loyalty_sheet.dart';
import 'package:food_delivery/features/cart/presentation/cart_controller.dart';
import 'package:food_delivery/features/loyalty/data/loyalty_repository.dart';
import 'package:food_delivery/features/loyalty/domain/loyalty.dart';
import 'package:food_delivery/features/orders/data/order_repository.dart';
import 'package:food_delivery/features/orders/domain/order.dart';

/// A Dio that records requests and answers with [respond].
class _Wire {
  _Wire(this.respond);

  final Response<dynamic> Function(RequestOptions) respond;
  final calls = <RequestOptions>[];

  Dio get dio => Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.add(options);
          final r = respond(options);
          if ((r.statusCode ?? 200) >= 400) {
            handler.reject(DioException(requestOptions: options, response: r));
          } else {
            handler.resolve(r);
          }
        },
      ),
    );
}

Response<dynamic> ok(RequestOptions o, Object data) =>
    Response(requestOptions: o, data: data, statusCode: 200);

const _orderJson = {
  'id': 1,
  'restaurant_id': 1,
  'restaurant_name': 'Bao',
  'status': 'pending',
  'address': 'Abay 1',
  'subtotal': 2000,
  'delivery_fee': 0,
  'total': 1800,
  'created_at': '2026-01-01T00:00:00',
  'items': <dynamic>[],
  'rating': null,
  'customer': {'id': 1, 'name': 'A', 'phone': null},
  'courier': null,
};

void main() {
  group('models', () {
    test('a quote with and without the usable amount', () {
      final full = LoyaltyQuote.fromJson({
        'balance': 200,
        'percent': 10,
        'max_share': 0.5,
        'usable': 150,
      });
      final bare = LoyaltyQuote.fromJson({
        'balance': 0,
        'percent': 0,
        'max_share': 0.5,
        'usable': null,
      });

      expect(full.usable, 150);
      expect(full.hasUsable, isTrue);
      expect(bare.hasUsable, isFalse);
      expect(bare.hasProgramme, isFalse);
    });

    test('a balance names its venue', () {
      final b = LoyaltyBalance.fromJson({
        'restaurant_id': 3,
        'restaurant_name': 'Bao Bar',
        'balance': 200.5,
      });

      expect(
        (b.restaurantId, b.restaurantName, b.balance),
        (3, 'Bao Bar', 200.5),
      );
    });

    test('an order reads what bonuses paid, and defaults to none', () {
      expect(
        Order.fromJson({..._orderJson, 'loyalty_spent': 200}).loyaltySpent,
        200,
      );
      expect(Order.fromJson(_orderJson).loyaltySpent, 0);
    });
  });

  group('the order request', () {
    Future<Map<String, dynamic>> bodyFor(CartState cart) async {
      final wire = _Wire((o) => ok(o, _orderJson));
      await OrderRepository(wire.dio).create(cart: cart, address: 'Abay 1');
      return wire.calls.single.data as Map<String, dynamic>;
    }

    test('asks for bonuses only when the diner switched them on', () async {
      expect(
        (await bodyFor(const CartState(restaurantId: 1)))
            .containsKey('use_loyalty'),
        isFalse,
      );
      expect(
        (await bodyFor(
          const CartState(restaurantId: 1, useLoyalty: true),
        ))['use_loyalty'],
        isTrue,
      );
    });

    test('a saved cart remembers the choice', () {
      final back = CartState.fromJson(
        const CartState(restaurantId: 1, useLoyalty: true).toJson(),
      );

      expect(back.useLoyalty, isTrue);
    });
  });

  group('LoyaltyRepository', () {
    test('asks for the quote with the food total', () async {
      final wire = _Wire(
        (o) => ok(o, {
          'balance': 200,
          'percent': 10,
          'max_share': 0.5,
          'usable': 200,
        }),
      );

      await LoyaltyRepository(wire.dio).quote(7, subtotal: 2000);

      expect(wire.calls.single.path, '/api/v1/me/loyalty/7');
      expect(wire.calls.single.queryParameters, {'subtotal': 2000.0});
    });

    test('saves the programme as fractions the server expects', () async {
      final wire = _Wire((o) => ok(o, {}));

      await LoyaltyRepository(wire.dio)
          .saveProgramme(3, percent: 5, maxShare: 0.5);

      expect(wire.calls.single.method, 'PUT');
      expect(wire.calls.single.path, '/api/v1/admin/restaurants/3/loyalty');
      expect(wire.calls.single.data, {'percent': 5.0, 'max_share': 0.5});
    });
  });

  group('the owner\'s sheet', () {
    Future<_Wire> open(
      WidgetTester tester,
      Response<dynamic> Function(RequestOptions) respond,
    ) async {
      tester.view.physicalSize =
          const Size(320, 640) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      final wire = _Wire(respond);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loyaltyRepositoryProvider.overrideWithValue(
              LoyaltyRepository(wire.dio),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            locale: const Locale('en'),
            home: const Scaffold(
              body: LoyaltySheet(restaurantId: 3, percent: 10, maxShare: 0.5),
            ),
          ),
        ),
      );
      return wire;
    }

    testWidgets('starts from what is saved and saves it as fractions', (
      tester,
    ) async {
      final wire = await open(tester, (o) => ok(o, {}));

      expect(find.text('10'), findsOneWidget);
      expect(find.text('50'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(wire.calls.single.data, {'percent': 10.0, 'max_share': 0.5});
      expect(tester.takeException(), isNull);
    });

    testWidgets('a plan without the feature is told it is Premium', (
      tester,
    ) async {
      await open(
        tester,
        (o) =>
            Response(requestOptions: o, statusCode: 403, data: {'detail': 'x'}),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Available on Premium'), findsOneWidget);
    });

    testWidgets('a silly rate is caught before it is sent', (tester) async {
      final wire = await open(tester, (o) => ok(o, {}));

      await tester.enterText(find.byType(TextField).first, '80');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(wire.calls, isEmpty);
    });
  });
}
