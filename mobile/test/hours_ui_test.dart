import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/l10n/l10n.dart';
import 'package:food_delivery/features/admin/data/hours_repository.dart';
import 'package:food_delivery/features/admin/presentation/admin_hours_sheet.dart';
import 'package:food_delivery/features/restaurants/domain/opening_hours.dart';
import 'package:food_delivery/features/restaurants/domain/restaurant.dart';
import 'package:food_delivery/features/restaurants/presentation/hours_text.dart';

Restaurant venue({
  bool isOpen = true,
  bool openNow = true,
  DateTime? opensAt,
}) => Restaurant(
  id: 1,
  name: 'Bao Bar',
  description: '',
  cuisine: 'Asian',
  rating: 4.5,
  ratingCount: 10,
  deliveryFee: 500,
  deliveryTimeMin: 30,
  isOpen: isOpen,
  openNow: openNow,
  opensAt: opensAt,
);

Widget app(Widget home, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: L10n.localizationsDelegates,
    supportedLocales: L10n.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: home),
  ),
);

/// Runs [read] with a BuildContext that has the app's localizations.
Future<T> withContext<T>(
  WidgetTester tester,
  T Function(BuildContext) read,
) async {
  late T out;
  await tester.pumpWidget(
    app(
      Builder(
        builder: (context) {
          out = read(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return out;
}

class _FakeHours extends HoursRepository {
  _FakeHours(this.week0) : super(Dio());

  final List<OpeningStretch> week0;
  List<OpeningStretch>? saved;

  @override
  Future<List<OpeningStretch>> week(int restaurantId) async => week0;

  @override
  Future<List<OpeningStretch>> save(
    int restaurantId,
    List<OpeningStretch> week,
  ) async {
    saved = week;
    return week;
  }
}

void main() {
  group('opensLabel', () {
    final monday8 = DateTime(2026, 9, 28, 8);

    testWidgets('says nothing about a venue that is open', (tester) async {
      final label = await withContext(
        tester,
        (c) => opensLabel(
          c,
          venue(opensAt: DateTime(2026, 9, 28, 10)),
          now: monday8,
        ),
      );
      expect(label, isNull);
    });

    testWidgets('says nothing about a venue the owner switched off', (
      tester,
    ) async {
      final label = await withContext(
        tester,
        (c) => opensLabel(
          c,
          venue(
            isOpen: false,
            openNow: false,
            opensAt: DateTime(2026, 9, 28, 10),
          ),
          now: monday8,
        ),
      );
      expect(label, isNull);
    });

    testWidgets('later today is just the time', (tester) async {
      final label = await withContext(
        tester,
        (c) => opensLabel(
          c,
          venue(openNow: false, opensAt: DateTime(2026, 9, 28, 10)),
          now: monday8,
        ),
      );
      expect(label, 'Opens at 10:00');
    });

    testWidgets('another day names the day', (tester) async {
      final label = await withContext(
        tester,
        (c) => opensLabel(
          c,
          venue(openNow: false, opensAt: DateTime(2026, 9, 29, 9, 5)),
          now: monday8,
        ),
      );
      expect(label, allOf(contains('Tue'), contains('09:05')));
    });
  });

  group('Restaurant.fromJson', () {
    Map<String, dynamic> json(Map<String, dynamic> extra) => {
      'id': 1,
      'name': 'Bao Bar',
      'cuisine': 'Asian',
      'rating': 4.5,
      'delivery_fee': 500,
      'delivery_time_min': 30,
      'is_open': true,
      ...extra,
    };

    test('keeps the venue clock as written', () {
      final r = Restaurant.fromJson(
        json({'open_now': false, 'opens_at': '2026-10-01T10:00:00+05:00'}),
      );

      expect(r.openNow, isFalse);
      // 10:00 where the kitchen is, whatever zone this phone is in.
      expect(r.opensAt, DateTime(2026, 10, 1, 10));
    });

    test('an older server that sends none means open', () {
      final r = Restaurant.fromJson(json({}));

      expect(r.openNow, isTrue);
      expect(r.opensAt, isNull);
      expect(r.hours, isEmpty);
      expect(r.loyaltyPercent, 0);
    });
  });

  group('HoursRepository.save', () {
    test('puts the whole week', () async {
      RequestOptions? sent;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              sent = options;
              handler.resolve(
                Response(requestOptions: options, data: [], statusCode: 200),
              );
            },
          ),
        );

      await HoursRepository(dio).save(4, const [
        OpeningStretch(weekday: 4, opens: '18:00', closes: '02:00'),
      ]);

      expect(sent!.method, 'PUT');
      expect(sent!.path, '/api/v1/admin/restaurants/4/hours');
      expect(sent!.data, [
        {'weekday': 4, 'opens': '18:00', 'closes': '02:00'},
      ]);
    });
  });

  testWidgets('the hours sheet fits 320px and saves the week it shows', (
    tester,
  ) async {
    tester.view.physicalSize =
        const Size(320, 640) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final repo = _FakeHours(const [
      OpeningStretch(weekday: 0, opens: '10:00', closes: '22:00'),
      OpeningStretch(weekday: 4, opens: '18:00', closes: '02:00'),
    ]);

    await tester.pumpWidget(
      app(
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => editHours(context, ref, 1),
            child: const Text('open'),
          ),
        ),
        overrides: [hoursRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Opening hours'), findsOneWidget);
    expect(find.textContaining('18:00'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Save'), 200);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.saved!.map((s) => s.weekday), [0, 4]);
    expect(tester.takeException(), isNull);
  });
}
