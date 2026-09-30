import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/api/api_client.dart';
import 'package:food_delivery/core/l10n/l10n.dart';
import 'package:food_delivery/features/admin/data/applications_repository.dart';
import 'package:food_delivery/features/admin/presentation/admin_screen.dart';
import 'package:food_delivery/features/admin/presentation/platform_applications_tab.dart';

void main() {
  test('the applications link names the platform tab and its sub-tab', () {
    expect(adminTabFor('applications'), (top: 3, platform: 4));
    expect(adminTabFor(null), isNull);
    expect(adminTabFor('nonsense'), isNull);
  });

  testWidgets('/admin?tab=applications opens on the applications list', (
    tester,
  ) async {
    tester.view.physicalSize =
        const Size(375, 812) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    // Anything else the screen asks for gets an empty answer.
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) =>
              h.resolve(Response(requestOptions: o, data: [], statusCode: 200)),
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          dioProvider.overrideWithValue(dio),
          pendingApplicationsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          locale: const Locale('ru'),
          home: const AdminScreen(tab: 'applications'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(PlatformApplicationsTab), findsOneWidget);
    expect(find.text('Заявок нет'), findsOneWidget);
  });
}
