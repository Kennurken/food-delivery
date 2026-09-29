import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/l10n/l10n.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/features/courier/data/earnings_repository.dart';
import 'package:food_delivery/features/courier/presentation/earnings_tab.dart';

/// The wallet at the narrowest phone worth supporting, in Russian, with the
/// longest things a row can hold. An overflow throws in tests, so getting to
/// the end means it fits.
void main() {
  testWidgets('the payout history fits a 320px phone', (tester) async {
    tester.view.physicalSize =
        const Size(320, 640) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);

    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final history = options.path.endsWith('/history');
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: history
                    ? {
                        'items': [
                          {
                            'order_id': 7,
                            'restaurant_name':
                                'Ресторан восточной кухни «Золотой Самарканд»',
                            'at': '2026-09-30T07:40:00',
                            'payout': 1250.5,
                            'pay_method': 'cash',
                            'cash_held': 128400,
                          },
                        ],
                        'next_before': 7,
                      }
                    : {
                        'days': 7,
                        'deliveries': 1,
                        'earned': 1250.5,
                        'cash_held': 128400,
                        'earned_all_time': 1250.5,
                        'deliveries_all_time': 1,
                        'by_day': const [],
                      },
              ),
            );
          },
        ),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          earningsRepositoryProvider.overrideWithValue(EarningsRepository(dio)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          locale: const Locale('ru'),
          home: const Scaffold(body: EarningsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Показать ещё'), 200);
    expect(find.textContaining('Золотой Самарканд'), findsOneWidget);
    expect(find.textContaining('наличные у вас'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
