import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/courier/domain/courier_earnings.dart';

Map<String, dynamic> _payload({
  double earned = 1200,
  double cashHeld = 4000,
  List<Map<String, dynamic>>? byDay,
}) => {
  'days': 7,
  'deliveries': 3,
  'earned': earned,
  'cash_held': cashHeld,
  'earned_all_time': 9000,
  'deliveries_all_time': 20,
  'by_day':
      byDay ??
      [
        {'day': '2026-09-23', 'deliveries': 2, 'earned': 800.0},
        {'day': '2026-09-22', 'deliveries': 1, 'earned': 400.0},
      ],
};

void main() {
  group('courier wallet', () {
    test('reads both sides of the ledger', () {
      final data = CourierEarnings.fromJson(_payload());

      expect(data.earned, 1200);
      expect(data.cashHeld, 4000);
      expect(data.deliveries, 3);
      expect(data.earnedAllTime, 9000);
      expect(data.byDay, hasLength(2));
    });

    test('survives a payload with nothing in it', () {
      final data = CourierEarnings.fromJson({});

      expect(data.earned, 0);
      expect(data.cashHeld, 0);
      expect(data.byDay, isEmpty);
    });

    test('accepts integer money from the wire', () {
      final data = CourierEarnings.fromJson(
        _payload(earned: 0)..['earned'] = 500,
      );

      expect(data.earned, 500.0);
    });

    test('peak is never zero, so the chart cannot divide by it', () {
      final flat = CourierEarnings.fromJson(
        _payload(
          byDay: [
            {'day': '2026-09-23', 'deliveries': 0, 'earned': 0.0},
          ],
        ),
      );

      expect(flat.peakDay, greaterThan(0));
    });

    test('peak tracks the best day', () {
      final data = CourierEarnings.fromJson(_payload());

      expect(data.peakDay, 800);
    });

    test('day labels drop the year', () {
      const day = EarningsDay(day: '2026-09-23', deliveries: 1, earned: 400);

      expect(day.shortLabel, '23.09');
    });

    test('an unexpected day format is shown as-is rather than mangled', () {
      const day = EarningsDay(day: 'today', deliveries: 1, earned: 400);

      expect(day.shortLabel, 'today');
    });
  });
}
