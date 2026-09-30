import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/features/admin/domain/venue_stats.dart';
import 'package:food_delivery/features/admin/presentation/stats_widgets.dart';

Map<String, dynamic> _payload(Map<String, dynamic> extra) => {
  'days': 30,
  'window_limit': 90,
  'orders': 3,
  'revenue': 3000,
  'average_check': 1000,
  'cancelled': 0,
  'cancel_rate': 0,
  ...extra,
};

void main() {
  group('reading the payload', () {
    test('peak hours and regulars', () {
      final hours = List<int>.filled(24, 0)
        ..[13] = 4
        ..[19] = 9;
      final data = VenueStats.fromJson(
        _payload({'by_hour': hours, 'customers': 10, 'repeat_customers': 4}),
      );

      expect(data.byHour[19], 9);
      expect(data.peakHourCount, 9);
      expect((data.customers, data.repeatCustomers), (10, 4));
    });

    test('an older server that sends none reads as nothing', () {
      final data = VenueStats.fromJson(_payload({}));

      expect(data.byHour, isEmpty);
      expect(data.customers, 0);
      expect(data.peakHourCount, 1); // never zero: a chart divides by it
    });
  });

  group('HourChart', () {
    Future<void> pump(
      WidgetTester tester,
      List<int> hours, {
      Size? size,
    }) async {
      if (size != null) {
        tester.view.physicalSize = size * tester.view.devicePixelRatio;
        addTearDown(tester.view.reset);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: HourChart(
                hours: hours,
                peak: hours.fold<int>(1, (a, b) => b > a ? b : a),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('fits a 320px phone and labels only a few hours', (
      tester,
    ) async {
      await pump(
        tester,
        List<int>.generate(24, (h) => h % 5),
        size: const Size(320, 640),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.text('7'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('draws nothing for a quiet venue', (tester) async {
      await pump(tester, List<int>.filled(24, 0));

      expect(find.byType(Container), findsNothing);
    });

    testWidgets('draws nothing without 24 hours', (tester) async {
      await pump(tester, const [1, 2, 3]);

      expect(find.byType(Container), findsNothing);
    });
  });
}
