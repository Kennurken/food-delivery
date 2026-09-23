import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/admin/domain/venue_stats.dart';

void main() {
  group('venue stats', () {
    final payload = {
      'days': 30,
      'window_limit': 90,
      'orders': 12,
      'revenue': 48000,
      'average_check': 4800,
      'cancelled': 2,
      'cancel_rate': 0.1667,
      'by_day': [
        {'day': '2026-09-23', 'orders': 5, 'revenue': 30000.0},
        {'day': '2026-09-22', 'orders': 5, 'revenue': 18000.0},
      ],
      'top_dishes': [
        {'name': 'Pork Bao', 'quantity': 9, 'revenue': 13500.0},
      ],
      'by_channel': {'delivery': 10, 'pickup': 2},
      'by_pay_method': {'cash': 8, 'online': 4},
    };

    test('reads the window the plan allows apart from the one in use', () {
      final data = VenueStats.fromJson(payload);

      expect(data.days, 30);
      expect(data.windowLimit, 90);
    });

    test('orders and revenue stay separate figures', () {
      final data = VenueStats.fromJson(payload);

      expect(data.orders, 12);
      expect(data.revenue, 48000);
      expect(data.averageCheck, 4800);
    });

    test('survives an empty payload', () {
      final data = VenueStats.fromJson({});

      expect(data.orders, 0);
      expect(data.revenue, 0);
      expect(data.byDay, isEmpty);
      expect(data.byChannel, isEmpty);
    });

    test('accepts integer money from the wire', () {
      final data = VenueStats.fromJson({...payload, 'revenue': 500});

      expect(data.revenue, 500.0);
    });

    test('peak is never zero so a chart cannot divide by it', () {
      final flat = VenueStats.fromJson({
        ...payload,
        'by_day': [
          {'day': '2026-09-23', 'orders': 0, 'revenue': 0.0},
        ],
      });

      expect(flat.peakDay, greaterThan(0));
    });

    test('channel counts survive the round trip', () {
      final data = VenueStats.fromJson(payload);

      expect(data.byChannel['delivery'], 10);
      expect(data.byPayMethod['online'], 4);
    });
  });

  group('platform revenue', () {
    final payload = {
      'days': 30,
      'orders': 20,
      'gross': 90000.0,
      'courier_payouts': 8000.0,
      'by_day': [
        {'day': '2026-09-23', 'orders': 20, 'gross': 90000.0},
      ],
      'by_plan': [
        {'plan_code': 'pro', 'restaurants': 2, 'gross': 90000.0},
        {'plan_code': 'basic', 'restaurants': 1, 'gross': 0.0},
      ],
      'top_restaurants': [
        {'id': 1, 'name': 'Bao Bar', 'orders': 20, 'gross': 90000.0},
      ],
    };

    test('gross and payouts are read as separate directions of money', () {
      final data = PlatformRevenue.fromJson(payload);

      expect(data.gross, 90000);
      expect(data.courierPayouts, 8000);
    });

    test('the daily series maps gross onto the shared chart shape', () {
      final data = PlatformRevenue.fromJson(payload);

      expect(data.byDay.single.revenue, 90000);
      expect(data.byDay.single.shortLabel, '23.09');
    });

    test('a venue with no sales still appears in the plan split', () {
      final data = PlatformRevenue.fromJson(payload);

      expect(data.byPlan, hasLength(2));
      expect(data.byPlan.last.restaurants, 1);
      expect(data.byPlan.last.gross, 0);
    });

    test('survives an empty payload', () {
      final data = PlatformRevenue.fromJson({});

      expect(data.gross, 0);
      expect(data.byPlan, isEmpty);
      expect(data.peakDay, greaterThan(0));
    });
  });
}
