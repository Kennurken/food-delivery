import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/notifications/push_route.dart';

void main() {
  group('routeForPush', () {
    test('a status change opens the order', () {
      expect(
        routeForPush({
          'order_id': '42',
          'status': 'preparing',
          'cause': 'status',
        }),
        '/orders/42',
      );
    });

    test(
      'an order id without a cause is a status push from an older server',
      () {
        expect(
          routeForPush({'order_id': '42', 'status': 'preparing'}),
          '/orders/42',
        );
        expect(pushCause({'order_id': '42'}), 'status');
      },
    );

    test('a chat message opens that order\'s chat', () {
      expect(routeForPush({'order_id': '42', 'cause': 'chat'}), '/chat/42');
    });

    test('a manager called in lands in the same chat', () {
      expect(
        routeForPush({'order_id': '42', 'cause': 'escalation'}),
        '/chat/42',
      );
    });

    test('a new application opens the admin applications tab', () {
      expect(
        routeForPush({'restaurant_id': '7', 'cause': 'application'}),
        '/admin?tab=applications',
      );
    });

    test('a decision on an application opens that venue\'s management', () {
      expect(
        routeForPush({'restaurant_id': '7', 'cause': 'approval'}),
        '/admin/restaurants/7',
      );
    });

    test('garbage opens nothing', () {
      expect(routeForPush({}), isNull);
      expect(routeForPush({'cause': 'mystery', 'order_id': '42'}), isNull);
      expect(routeForPush({'order_id': 'abc'}), isNull);
      expect(routeForPush({'order_id': '0'}), isNull);
      expect(routeForPush({'order_id': '-3', 'cause': 'chat'}), isNull);
      expect(routeForPush({'cause': 'chat'}), isNull);
      expect(routeForPush({'cause': 'status'}), isNull);
      expect(routeForPush({'cause': 'approval'}), isNull);
      expect(routeForPush({'cause': 'approval', 'restaurant_id': 'x'}), isNull);
      expect(routeForPush({'cause': 42, 'restaurant_id': null}), isNull);
    });
  });

  test(
    'only pushes the live socket does not carry get a foreground banner',
    () {
      // Status and chat already arrive over the socket with their own banner.
      expect(showsInForeground({'order_id': '42', 'cause': 'status'}), isFalse);
      expect(showsInForeground({'order_id': '42'}), isFalse);
      expect(showsInForeground({'order_id': '42', 'cause': 'chat'}), isFalse);
      expect(
        showsInForeground({'order_id': '42', 'cause': 'escalation'}),
        isTrue,
      );
      expect(
        showsInForeground({'restaurant_id': '7', 'cause': 'application'}),
        isTrue,
      );
      expect(
        showsInForeground({'restaurant_id': '7', 'cause': 'approval'}),
        isTrue,
      );
      expect(showsInForeground({}), isFalse);
    },
  );
}
