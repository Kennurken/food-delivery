import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_delivery/features/courier/data/earnings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_delivery/features/courier/domain/payout_row.dart';

void main() {
  group('PayoutRow.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'order_id': 12,
        'restaurant_name': 'Bao Bar',
        'at': '2026-09-30T12:40:00',
        'payout': 350.0,
        'pay_method': 'cash',
        'cash_held': 2000.0,
      };

      final row = PayoutRow.fromJson(json);

      expect(row.orderId, 12);
      expect(row.restaurantName, 'Bao Bar');
      expect(
        row.at.toUtc(),
        DateTime.utc(2026, 9, 30, 12, 40),
      ); // API time is UTC
      expect(row.payout, 350.0);
      expect(row.payMethod, 'cash');
      expect(row.cashHeld, 2000.0);
    });

    test('handles missing/null fields with defaults', () {
      final json = <String, dynamic>{};

      final row = PayoutRow.fromJson(json);

      expect(row.orderId, 0);
      expect(row.restaurantName, '');
      expect(row.at, DateTime.fromMillisecondsSinceEpoch(0));
      expect(row.payout, 0);
      expect(row.payMethod, '');
      expect(row.cashHeld, 0);
    });
  });

  group('PayoutPage.fromJson', () {
    test('parses items and next_before', () {
      final json = {
        'items': [
          {
            'order_id': 1,
            'restaurant_name': 'A',
            'at': '2026-09-30T10:00:00',
            'payout': 100.0,
            'pay_method': 'card',
            'cash_held': 0,
          },
          {
            'order_id': 2,
            'restaurant_name': 'B',
            'at': '2026-09-30T11:00:00',
            'payout': 200.0,
            'pay_method': 'cash',
            'cash_held': 500.0,
          },
        ],
        'next_before': 2,
      };

      final page = PayoutPage.fromJson(json);

      expect(page.items.length, 2);
      expect(page.items[0].orderId, 1);
      expect(page.items[1].orderId, 2);
      expect(page.nextBefore, 2);
    });

    test('handles next_before null', () {
      final json = {
        'items': [
          {
            'order_id': 1,
            'restaurant_name': 'A',
            'at': '2026-09-30T10:00:00',
            'payout': 100.0,
            'pay_method': 'card',
            'cash_held': 0,
          },
        ],
        'next_before': null,
      };

      final page = PayoutPage.fromJson(json);

      expect(page.items.length, 1);
      expect(page.nextBefore, null);
    });

    test('handles missing items and next_before', () {
      final json = <String, dynamic>{};

      final page = PayoutPage.fromJson(json);

      expect(page.items, isEmpty);
      expect(page.nextBefore, null);
    });
  });

  group('EarningsRepository.history', () {
    late Dio dio;
    late EarningsRepository repo;
    late Map<String, dynamic>? capturedQuery;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedQuery = options.queryParameters;
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'items': [], 'next_before': null},
                statusCode: 200,
              ),
            );
          },
        ),
      );
      repo = EarningsRepository(dio);
    });

    test('history() sends limit=20, no before', () async {
      await repo.history();

      expect(capturedQuery?['limit'], 20);
      expect(capturedQuery?.containsKey('before'), false);
    });

    test('history(before: 42) sends limit=20 and before=42', () async {
      await repo.history(before: 42);

      expect(capturedQuery?['limit'], 20);
      expect(capturedQuery?['before'], 42);
    });
  });

  group('EarningsRepository pagination', () {
    late Dio dio;
    late EarningsRepository repo;
    int callCount = 0;

    setUp(() {
      callCount = 0;
      dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            callCount++;
            if (callCount == 1) {
              // First page
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'items': [
                      {
                        'order_id': 1,
                        'restaurant_name': 'First',
                        'at': '2026-09-30T10:00:00',
                        'payout': 100.0,
                        'pay_method': 'card',
                        'cash_held': 0,
                      },
                    ],
                    'next_before': 1,
                  },
                  statusCode: 200,
                ),
              );
            } else {
              // Second page
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'items': [
                      {
                        'order_id': 2,
                        'restaurant_name': 'Second',
                        'at': '2026-09-30T11:00:00',
                        'payout': 200.0,
                        'pay_method': 'cash',
                        'cash_held': 500.0,
                      },
                    ],
                    'next_before': null,
                  },
                  statusCode: 200,
                ),
              );
            }
          },
        ),
      );
      repo = EarningsRepository(dio);
    });

    test('second page appends and next_before becomes null', () async {
      final page1 = await repo.history();
      expect(page1.items.length, 1);
      expect(page1.nextBefore, 1);

      final page2 = await repo.history(before: 1);
      expect(page2.items.length, 1);
      expect(page2.nextBefore, null);

      // Verify combined
      final combined = [...page1.items, ...page2.items];
      expect(combined.length, 2);
      expect(combined[0].orderId, 1);
      expect(combined[1].orderId, 2);
    });
  });

  group('PayoutHistory', () {
    Map<String, dynamic> page(List<int> ids, int? next) => {
      'items': [
        for (final id in ids)
          {
            'order_id': id,
            'restaurant_name': 'Bao Bar',
            'at': '2026-09-30T07:40:00',
            'payout': 350,
            'pay_method': 'cash',
            'cash_held': 0,
          },
      ],
      'next_before': next,
    };

    ProviderContainer containerServing(List<Map<String, dynamic>> pages) {
      var served = 0;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response(
                requestOptions: options,
                data: pages[served++],
                statusCode: 200,
              ),
            ),
          ),
        );
      final container = ProviderContainer(
        overrides: [
          earningsRepositoryProvider.overrideWithValue(EarningsRepository(dio)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('loading more appends and keeps the rows it had', () async {
      final container = containerServing([
        page([3, 2], 2),
        page([1], null),
      ]);
      final first = await container.read(payoutHistoryProvider.future);
      expect(first.rows.map((r) => r.orderId), [3, 2]);
      expect(first.hasMore, isTrue);

      final more = container.read(payoutHistoryProvider.notifier).loadMore();
      // While the page is on its way the rows stay on screen.
      final during = container.read(payoutHistoryProvider).value!;
      expect(during.loadingMore, isTrue);
      expect(during.rows.map((r) => r.orderId), [3, 2]);
      await more;

      final after = container.read(payoutHistoryProvider).value!;
      expect(after.rows.map((r) => r.orderId), [3, 2, 1]);
      expect(after.hasMore, isFalse);
      expect(after.loadingMore, isFalse);
    });

    test('a failed page keeps the rows and allows another try', () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.queryParameters.containsKey('before')) {
                handler.reject(
                  DioException(requestOptions: options, message: 'offline'),
                );
              } else {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: page([3, 2], 2),
                    statusCode: 200,
                  ),
                );
              }
            },
          ),
        );
      final container = ProviderContainer(
        overrides: [
          earningsRepositoryProvider.overrideWithValue(EarningsRepository(dio)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(payoutHistoryProvider.future);

      await expectLater(
        container.read(payoutHistoryProvider.notifier).loadMore(),
        throwsA(isA<DioException>()),
      );

      final now = container.read(payoutHistoryProvider).value!;
      expect(now.rows.map((r) => r.orderId), [3, 2]);
      expect(now.loadingMore, isFalse);
      expect(now.hasMore, isTrue);
    });

    test('the delivery time is read as UTC', () async {
      final container = containerServing([
        page([1], null),
      ]);
      final rows = (await container.read(payoutHistoryProvider.future)).rows;

      expect(rows.single.at.toUtc(), DateTime.utc(2026, 9, 30, 7, 40));
    });
  });
}
