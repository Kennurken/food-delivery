import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/orders/data/order_repository.dart';
import 'package:food_delivery/features/restaurants/data/restaurant_repository.dart';
import 'package:food_delivery/features/restaurants/domain/review.dart';

const _order = {
  'id': 1,
  'restaurant_id': 1,
  'restaurant_name': 'Bao',
  'status': 'delivered',
  'address': 'Abay 1',
  'subtotal': 1,
  'delivery_fee': 0,
  'total': 1,
  'created_at': '2026-01-01T00:00:00',
  'items': <dynamic>[],
  'rating': 5,
  'customer': {'id': 1, 'name': 'A', 'phone': null},
  'courier': null,
};

Dio _dio(List<RequestOptions> log, Object answer) => Dio()
  ..interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        log.add(options);
        handler.resolve(
          Response(requestOptions: options, data: answer, statusCode: 200),
        );
      },
    ),
  );

void main() {
  test('a review reads what the server sends, and tolerates gaps', () {
    final full = Review.fromJson({
      'order_id': 7,
      'rating': 4,
      'text': 'Tasty',
      'author': 'Алия К.',
      'at': '2026-09-30T07:40:00',
      'reply': 'Thanks!',
    });
    final bare = Review.fromJson({'order_id': 8});

    expect((full.rating, full.author, full.reply), (4, 'Алия К.', 'Thanks!'));
    expect(full.at!.toUtc(), DateTime.utc(2026, 9, 30, 7, 40));
    expect((bare.text, bare.author, bare.reply, bare.at), ('', '', null, null));
  });

  group('rating', () {
    test('sends the words only when there are some', () async {
      final log = <RequestOptions>[];
      final repo = OrderRepository(_dio(log, _order));

      await repo.rate(1, 5);
      await repo.rate(1, 5, review: '   ');
      await repo.rate(1, 4, review: '  Great  ');

      expect(log[0].data, {'rating': 5});
      expect(log[1].data, {'rating': 5});
      expect(log[2].data, {'rating': 4, 'review': 'Great'});
    });
  });

  group('the venue\'s reviews', () {
    test('asks for a small page and reads the items', () async {
      final log = <RequestOptions>[];
      final repo = RestaurantRepository(
        _dio(log, {
          'items': [
            {'order_id': 2, 'rating': 5, 'text': 'Yum', 'author': 'Ая К.'},
          ],
          'next_before': null,
        }),
      );

      final rows = await repo.reviews(3);

      expect(log.single.path, '/api/v1/restaurants/3/reviews');
      expect(log.single.queryParameters, {'limit': 10});
      expect(rows.single.text, 'Yum');
    });

    test('the provider serves the same', () async {
      final container = ProviderContainer(
        overrides: [
          restaurantRepositoryProvider.overrideWithValue(
            RestaurantRepository(
              _dio([], {'items': <dynamic>[], 'next_before': null}),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(restaurantReviewsProvider(3).future),
        isEmpty,
      );
    });
  });
}
