import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/anim_icon.dart';
import 'package:food_delivery/core/widgets/empty_state.dart';
import 'package:food_delivery/features/admin/domain/venue_stats.dart';
import 'package:food_delivery/features/admin/presentation/manage_actions.dart';
import 'package:food_delivery/features/admin/presentation/stats_widgets.dart';

/// Layout on a phone.
///
/// Flutter turns an overflow into a thrown error in tests, so pumping a widget
/// at a real phone size and finding no exception is a genuine check that it
/// fits — which is the bug class that hides from a desktop window.
const _phone = Size(375, 812);

/// The narrowest phone still worth supporting. Long Russian labels are where
/// a row gives up first.
const _narrow = Size(320, 640);

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget child, {

  /// EmptyState scrolls itself and is built to fill a viewport; nesting it in
  /// another scroll view hands it an infinite height and breaks its layout for
  /// reasons the product never meets.
  bool scroll = true,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        // Scrollable, because that is how every one of these blocks is used.
        // A fixed-height box invents vertical overflows the product cannot
        // have, and that noise hides the horizontal ones it can.
        body: SafeArea(
          child: scroll
              ? SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: child,
                  ),
                )
              : Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

Widget get _manageRow => ManageActions(
  actions: [
    ManageAction(shape: AnimShape.pot, label: 'Кухня', onTap: () {}),
    ManageAction(shape: AnimShape.stop, label: 'Стоп-лист', onTap: () {}),
    ManageAction(shape: AnimShape.grid, label: 'План зала', onTap: () {}),
    ManageAction(shape: AnimShape.tag, label: 'Промокоды', onTap: () {}),
    ManageAction(shape: AnimShape.bell, label: 'Брони', onTap: () {}),
    ManageAction(shape: AnimShape.card, label: 'Оплата', onTap: () {}),
  ],
);

Widget get _statsBlock => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    StatGrid(
      tiles: const [
        StatTile(label: 'Выручка', value: '1 184 500 ₸'),
        StatTile(label: 'Заказов', value: '640'),
        StatTile(label: 'Средний чек', value: '12 883 ₸'),
        StatTile(label: 'Отменено', value: '31 · 5%'),
      ],
    ),
    const SizedBox(height: 18),
    DayChart(
      days: const [
        StatsDay(day: '2026-09-24', orders: 9, revenue: 34000),
        StatsDay(day: '2026-09-23', orders: 6, revenue: 21000),
        StatsDay(day: '2026-09-22', orders: 11, revenue: 47000),
        StatsDay(day: '2026-09-21', orders: 4, revenue: 12000),
        StatsDay(day: '2026-09-20', orders: 8, revenue: 29000),
      ],
      peak: 47000,
    ),
    const RankRow(
      title: 'Очень длинное название блюда, которое не помещается',
      subtitle: '× 41 · 61 500 ₸',
      value: '1 261 500 ₸',
    ),
  ],
);

void main() {
  group('fits a phone', () {
    testWidgets('the venue tool row', (tester) async {
      await _pumpAt(tester, _phone, _manageRow);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the venue tool row on a narrow phone', (tester) async {
      await _pumpAt(tester, _narrow, _manageRow);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the stats block, with numbers that do not shrink', (
      tester,
    ) async {
      await _pumpAt(tester, _phone, _statsBlock);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the stats block on a narrow phone', (tester) async {
      await _pumpAt(tester, _narrow, _statsBlock);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a day chart with a fortnight of bars', (tester) async {
      await _pumpAt(
        tester,
        _narrow,
        DayChart(
          days: [
            for (var i = 0; i < 14; i++)
              StatsDay(
                day: '2026-09-${10 + i}',
                orders: i,
                revenue: 1000.0 * i,
              ),
          ],
          peak: 13000,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty state with a long hint', (tester) async {
      await _pumpAt(
        tester,
        _narrow,
        const EmptyState(
          shape: AnimShape.scooter,
          title: 'Нет активных доставок',
          hint: 'Примите заказ во вкладке «Доступные», и он появится здесь',
        ),
        scroll: false,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('text scaled up for accessibility', (tester) async {
      // Someone with large type turned on is the other way a row gives up.
      tester.view.physicalSize = _phone * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _manageRow,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
    });
  });
}
