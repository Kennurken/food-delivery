import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/l10n/l10n.dart';
import 'package:food_delivery/features/admin/data/applications_repository.dart';
import 'package:food_delivery/features/admin/domain/application.dart';
import 'package:food_delivery/features/admin/presentation/platform_applications_tab.dart';
import 'package:food_delivery/features/restaurants/domain/restaurant.dart';

const _row = {
  'restaurant_id': 7,
  'name': 'Кафе «Дастархан»',
  'cuisine': 'Казахская',
  'description': 'Семейное кафе',
  'city': 'Алматы',
  'has_couriers': false,
  'owner_name': 'Айгерим',
  'owner_phone': '+77011234567',
  'owner_email': 'a@cafe.kz',
};

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
  test('an application reads who applied and their courier answer', () {
    final a = Application.fromJson(_row);

    expect(
      (a.name, a.hasCouriers, a.ownerPhone),
      ('Кафе «Дастархан»', false, '+77011234567'),
    );
  });

  test('a venue defaults to approved for an older server', () {
    final r = Restaurant.fromJson({
      'id': 1,
      'name': 'X',
      'cuisine': 'Y',
      'rating': 4,
      'delivery_fee': 1,
      'delivery_time_min': 1,
      'is_open': true,
    });

    expect(
      (r.approval, r.isPending, r.offersDelivery),
      ('approved', false, true),
    );
    expect(
      Restaurant.fromJson({
        'id': 1,
        'name': 'X',
        'cuisine': 'Y',
        'rating': 4,
        'delivery_fee': 1,
        'delivery_time_min': 1,
        'is_open': true,
        'approval': 'pending',
      }).isPending,
      isTrue,
    );
  });

  test(
    'deciding posts the choice, and the reason only when there is one',
    () async {
      final log = <RequestOptions>[];
      final repo = ApplicationsRepository(_dio(log, (_) => {}));

      await repo.decide(7, approve: true);
      await repo.decide(7, approve: false, reason: '  Not a restaurant ');
      await repo.decide(7, approve: false, reason: '   ');

      expect(log[0].path, '/api/v1/admin/restaurants/7/approval');
      expect(log[0].data, {'approve': true});
      expect(log[1].data, {'approve': false, 'reason': 'Not a restaurant'});
      expect(log[2].data, {'approve': false});
    },
  );

  testWidgets('the queue shows who to call and lets the admin approve', (
    tester,
  ) async {
    tester.view.physicalSize =
        const Size(320, 640) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    final log = <RequestOptions>[];
    final dio = _dio(log, (o) => o.method == 'GET' ? [_row] : {});

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          applicationsRepositoryProvider.overrideWithValue(
            ApplicationsRepository(dio),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          locale: const Locale('ru'),
          home: const Scaffold(body: PlatformApplicationsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Дастархан'), findsOneWidget);
    expect(find.text('Без курьеров: самовывоз и столик'), findsOneWidget);
    expect(find.textContaining('+77011234567'), findsOneWidget);

    await tester.tap(find.text('Одобрить'));
    await tester.pumpAndSettle();

    expect(
      log.any((o) => o.method == 'POST' && o.data['approve'] == true),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejecting asks for a reason, and cancelling decides nothing', (
    tester,
  ) async {
    final log = <RequestOptions>[];
    final dio = _dio(log, (o) => o.method == 'GET' ? [_row] : {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          applicationsRepositoryProvider.overrideWithValue(
            ApplicationsRepository(dio),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          locale: const Locale('ru'),
          home: const Scaffold(body: PlatformApplicationsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Отклонить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(log.where((o) => o.method == 'POST'), isEmpty);
  });
}
