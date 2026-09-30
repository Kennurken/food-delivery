import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/admin/domain/venue_stats.dart';
import 'package:food_delivery/features/admin/floor_plan/data/floor_plan_repository.dart';
import 'package:food_delivery/features/admin/presentation/stats_widgets.dart';

Dio _dio(List<RequestOptions> log, Object data) => Dio()
  ..interceptors.add(
    InterceptorsWrapper(
      onRequest: (o, h) {
        log.add(o);
        h.resolve(Response(requestOptions: o, statusCode: 200, data: data));
      },
    ),
  );

void main() {
  test('the comparison is read when the server sends it', () {
    final s = VenueStats.fromJson({
      'days': 7,
      'orders': 4,
      'orders_change_pct': 100.0,
      'revenue_change_pct': -12.5,
    });

    expect((s.ordersChangePct, s.revenueChangePct), (100.0, -12.5));
  });

  test('no baseline means no percentage, not zero', () {
    final s = VenueStats.fromJson({'days': 7, 'orders_change_pct': null});

    expect(s.ordersChangePct, isNull);
    expect(s.revenueChangePct, isNull);
  });

  test('a change is written with its sign', () {
    expect(formatChange(12), '+12 %');
    expect(formatChange(-12.5), '−12.5 %');
    expect(formatChange(0), '0 %');
  });

  test('the print link comes from the server', () async {
    final log = <RequestOptions>[];
    final url = await FloorPlanRepository(
      _dio(log, {'url': 'https://x/api/v1/qr-sheet/abc', 'expires_in': 600}),
    ).qrSheetLink(3);

    expect(url, 'https://x/api/v1/qr-sheet/abc');
    expect(
      (log.single.method, log.single.path),
      ('POST', '/api/v1/admin/floors/3/qr-sheet'),
    );
  });

  test('a table link prefers the server public url', () async {
    final qr = await FloorPlanRepository(
      _dio([], {'token': '1.2.ab', 'url': 'https://app/#/t/1.2.ab'}),
    ).tableQr(3, 2);

    expect(qr.url, 'https://app/#/t/1.2.ab');
    expect(qr.token, '1.2.ab');
  });
}
