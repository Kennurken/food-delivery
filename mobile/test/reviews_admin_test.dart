import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/l10n/l10n.dart';
import 'package:food_delivery/features/admin/data/reviews_admin_repository.dart';
import 'package:food_delivery/features/admin/presentation/admin_reviews_sheet.dart';
import 'package:food_delivery/features/restaurants/data/restaurant_repository.dart';

Dio _dio(List<RequestOptions> log, Object Function(RequestOptions) answer) =>
    Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            log.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                data: answer(options),
                statusCode: 200,
              ),
            );
          },
        ),
      );

void main() {
  test('answering posts the trimmed text to the order\'s review', () async {
    final log = <RequestOptions>[];

    await ReviewsAdminRepository(_dio(log, (_) => {})).reply(9, '  Thanks!  ');

    expect(log.single.method, 'POST');
    expect(log.single.path, '/api/v1/admin/orders/9/review-reply');
    expect(log.single.data, {'text': 'Thanks!'});
  });

  testWidgets('the owner sees the reviews at 320px and can answer one', (
    tester,
  ) async {
    tester.view.physicalSize =
        const Size(320, 640) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final log = <RequestOptions>[];
    final dio = _dio(log, (o) {
      if (o.method == 'POST') return {};
      return {
        'items': [
          {
            'order_id': 5,
            'rating': 3,
            'text': 'Очень длинный отзыв про доставку, которая опоздала на сорок минут',
            'author': 'Алия К.',
            'reply': null,
          },
        ],
        'next_before': null,
      };
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          restaurantRepositoryProvider.overrideWithValue(
            RestaurantRepository(dio),
          ),
          reviewsAdminRepositoryProvider.overrideWithValue(
            ReviewsAdminRepository(dio),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          locale: const Locale('ru'),
          home: const Scaffold(body: ReviewsSheet(restaurantId: 1)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('опоздала'), findsOneWidget);
    await tester.tap(find.text('Ответить'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Извините!');
    await tester.tap(find.text('Отправить'));
    await tester.pumpAndSettle();

    final post = log.firstWhere((o) => o.method == 'POST');
    expect(post.path, '/api/v1/admin/orders/5/review-reply');
    expect(post.data, {'text': 'Извините!'});
    expect(tester.takeException(), isNull);
  });
}
