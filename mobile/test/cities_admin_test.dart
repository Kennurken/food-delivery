import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/l10n/l10n.dart';
import 'package:food_delivery/features/admin/data/cities_admin_repository.dart';
import 'package:food_delivery/features/admin/domain/admin_city.dart';
import 'package:food_delivery/features/admin/presentation/platform_cities_tab.dart';

const _almaty = {
  'id': 1,
  'slug': 'almaty',
  'name': 'Алматы',
  'name_in': 'Алматы',
  'lat': 43.2,
  'lng': 76.9,
  'utc_offset_min': 300,
  'is_active': true,
  'sort_order': 0,
  'venues': 3,
};

/// A Dio that records what was sent and answers with [answer].
class _Recorder {
  _Recorder(this.answer);

  final Object answer;
  final calls = <RequestOptions>[];

  Dio get dio => Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          calls.add(options);
          handler.resolve(
            Response(requestOptions: options, data: answer, statusCode: 200),
          );
        },
      ),
    );
}

void main() {
  group('AdminCity.fromJson', () {
    test('reads every field', () {
      final city = AdminCity.fromJson(_almaty);

      expect(city.slug, 'almaty');
      expect(city.nameIn, 'Алматы');
      expect(city.utcOffsetMin, 300);
      expect(city.isActive, isTrue);
      expect(city.venues, 3);
    });

    test('tolerates the optional ones being absent', () {
      final city = AdminCity.fromJson({
        'id': 2,
        'slug': 'astana',
        'name': 'Астана',
        'is_active': false,
      });

      expect(city.nameIn, isNull);
      expect(city.lat, isNull);
      expect(city.venues, 0);
      expect(city.isActive, isFalse);
    });
  });

  group('CitiesAdminRepository', () {
    test('create posts the address, name and declined name', () async {
      final rec = _Recorder(_almaty);

      await CitiesAdminRepository(rec.dio)
          .create(slug: 'shymkent', name: 'Шымкент', nameIn: 'Шымкенте');

      expect(rec.calls.single.method, 'POST');
      expect(rec.calls.single.path, '/api/v1/admin/cities');
      expect(rec.calls.single.data, {
        'slug': 'shymkent',
        'name': 'Шымкент',
        'name_in': 'Шымкенте',
      });
    });

    test('create leaves the declined name out when there is none', () async {
      final rec = _Recorder(_almaty);

      await CitiesAdminRepository(rec.dio).create(slug: 'oral', name: 'Орал');

      expect((rec.calls.single.data as Map).containsKey('name_in'), isFalse);
    });

    test('update patches only what changed', () async {
      final rec = _Recorder(_almaty);

      await CitiesAdminRepository(rec.dio).update(3, {'is_active': false});

      expect(rec.calls.single.method, 'PATCH');
      expect(rec.calls.single.path, '/api/v1/admin/cities/3');
      expect(rec.calls.single.data, {'is_active': false});
    });
  });

  testWidgets('the tab lists every city at 320px and opens the add sheet', (
    tester,
  ) async {
    tester.view.physicalSize =
        const Size(320, 640) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final rec = _Recorder([
      _almaty,
      {
        ..._almaty,
        'id': 2,
        'slug': 'astana',
        'name': 'Астана',
        'is_active': false,
      },
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          citiesAdminRepositoryProvider.overrideWithValue(
            CitiesAdminRepository(rec.dio),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          locale: const Locale('ru'),
          home: const Scaffold(body: PlatformCitiesTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Алматы'), findsOneWidget);
    expect(find.text('Астана'), findsOneWidget);
    expect(find.textContaining('/almaty/'), findsOneWidget);
    // A switched-off city is still listed, with its switch off.
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.map((s) => s.value), [true, false]);

    await tester.tap(find.text('Добавить город'));
    await tester.pumpAndSettle();
    expect(find.text('Адрес на сайте'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
