import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/l10n/l10n.dart';
import 'package:food_delivery/core/l10n/locale_controller.dart';
import 'package:food_delivery/features/admin/data/admin_repository.dart';
import 'package:food_delivery/features/auth/domain/user.dart';
import 'package:food_delivery/features/auth/presentation/auth_controller.dart';
import 'package:food_delivery/features/auth/presentation/login_screen.dart';
import 'package:food_delivery/features/auth/presentation/register_screen.dart';
import 'package:food_delivery/features/loyalty/data/loyalty_repository.dart';
import 'package:food_delivery/features/profile/data/account_repository.dart';
import 'package:food_delivery/features/profile/data/profile_repository.dart';
import 'package:food_delivery/features/profile/domain/meta.dart';
import 'package:food_delivery/features/profile/presentation/profile_screen.dart';

Dio _dio(List<RequestOptions> log, Object? Function(RequestOptions) answer) =>
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

/// Nobody signed in, without touching secure storage or the network.
class _SignedOut extends AuthController {
  @override
  Future<User?> build() async => null;
}

class _SignedIn extends AuthController {
  _SignedIn(this.user);

  final User user;

  @override
  Future<User?> build() async => user;
}

class _DeviceLocale extends LocaleController {
  @override
  Future<Locale?> build() async => null;
}

Future<void> _pumpProfile(WidgetTester tester, {required bool guest}) async {
  // Tall enough that the whole list is built, the legal card at its end too.
  tester.view.physicalSize =
      const Size(375, 2400) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  final user = User(
    id: 3,
    email: guest ? 'guest.ab12@qr.invalid' : 'user@food.dev',
    name: guest ? 'Стол 5' : 'Айгерим',
    role: 'customer',
    isGuest: guest,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authControllerProvider.overrideWith(() => _SignedIn(user)),
        localeControllerProvider.overrideWith(_DeviceLocale.new),
        addressesProvider.overrideWith((ref) async => []),
        myBonusesProvider.overrideWith((ref) async => []),
        metaProvider.overrideWith((ref) async => _meta),
      ],
      child: MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('ru'),
        home: const ProfileScreen(),
      ),
    ),
  );
  // Once for the providers to resolve, once for the entrance animations of
  // what that built: flutter_animate starts each on a zero-length timer.
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

const _meta = Meta(
  supportEmail: 'help@food.dev',
  supportPhone: '+77010000000',
  privacyUrl: 'https://food.dev/privacy',
  termsUrl: 'https://food.dev/terms',
);

Future<void> _pump(WidgetTester tester, Widget screen, {Meta? meta}) async {
  tester.view.physicalSize =
      const Size(375, 812) * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authControllerProvider.overrideWith(_SignedOut.new),
        // No meta = still loading, for as long as the test runs.
        metaProvider.overrideWith(
          (ref) => meta == null ? Completer<Meta>().future : Future.value(meta),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('ru'),
        home: screen,
      ),
    ),
  );
  // Entrance animations; the login backdrop loops, so no pumpAndSettle.
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  test('changing the password posts both passwords to /me/password', () async {
    final log = <RequestOptions>[];
    await AccountRepository(_dio(log, (_) => null))
        .changePassword(current: 'old-secret', next: 'new-secret-1');

    expect(
      (log.single.method, log.single.path),
      ('POST', '/api/v1/me/password'),
    );
    expect(log.single.data, {
      'current_password': 'old-secret',
      'new_password': 'new-secret-1',
    });
  });

  test(
    'deleting the account is a DELETE on /me carrying the password',
    () async {
      final log = <RequestOptions>[];
      await AccountRepository(_dio(log, (_) => null))
          .deleteAccount('secret123');

      expect((log.single.method, log.single.path), ('DELETE', '/api/v1/me'));
      expect(log.single.data, {'password': 'secret123'});
    },
  );

  test('resetting an owner returns the temporary password', () async {
    final log = <RequestOptions>[];
    final temporary = await AdminRepository(
      _dio(
        log,
        (_) => {'email': 'owner@x.kz', 'temporary_password': 'Kx7-pq2-Lm9'},
      ),
    ).resetPassword('owner@x.kz');

    expect(temporary, 'Kx7-pq2-Lm9');
    expect(
      (log.single.method, log.single.path),
      ('POST', '/api/v1/platform/users/reset-password'),
    );
    expect(log.single.data, {'email': 'owner@x.kz'});
  });

  test('meta reads the legal links and support contacts', () async {
    final log = <RequestOptions>[];
    final meta = await AccountRepository(
      _dio(
        log,
        (_) => {
          'support_email': 'help@food.dev',
          'support_phone': '+77010000000',
          'privacy_url': 'https://food.dev/privacy',
          'terms_url': 'https://food.dev/terms',
        },
      ),
    ).meta();

    expect(log.single.path, '/api/v1/meta');
    expect(
      (meta.supportEmail, meta.supportPhone, meta.privacyUrl, meta.termsUrl),
      (
        'help@food.dev',
        '+77010000000',
        'https://food.dev/privacy',
        'https://food.dev/terms',
      ),
    );
    expect(meta.hasSupport, isTrue);
  });

  test('a platform with no support contacts has none to offer', () {
    final meta = Meta.fromJson({
      'support_email': null,
      'support_phone': '  ',
      'privacy_url': 'https://food.dev/privacy',
      'terms_url': 'https://food.dev/terms',
    });

    expect((meta.supportEmail, meta.supportPhone), (null, null));
    expect(meta.hasSupport, isFalse);
  });

  testWidgets('forgot password explains the way back and who to contact', (
    tester,
  ) async {
    await _pump(tester, const LoginScreen(), meta: _meta);

    await tester.tap(find.text('Забыли пароль?'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Сброс пароля по e-mail пока недоступен.'),
      findsOneWidget,
    );
    expect(find.text('help@food.dev'), findsOneWidget);
    expect(find.text('+77010000000'), findsOneWidget);
  });

  testWidgets(
    'forgot password without contacts still opens, just without them',
    (tester) async {
      await _pump(
        tester,
        const LoginScreen(),
        meta: const Meta(privacyUrl: 'https://p', termsUrl: 'https://t'),
      );

      await tester.tap(find.text('Забыли пароль?'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Гости могут просто создать новый аккаунт.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.mail_outline), findsNothing);
    },
  );

  testWidgets('register names the terms and the privacy policy as links', (
    tester,
  ) async {
    await _pump(tester, const RegisterScreen(), meta: _meta);

    for (final phrase in [
      'Условиями использования',
      'Политикой конфиденциальности',
    ]) {
      expect(
        find.ancestor(of: find.text(phrase), matching: find.byType(InkWell)),
        findsOneWidget,
      );
    }
  });

  testWidgets('until the URLs arrive the phrases are plain text, not links', (
    tester,
  ) async {
    await _pump(tester, const RegisterScreen());

    expect(
      find.textContaining('Условиями использования', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Условиями использования'),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('a signed-in customer can change the password or delete', (
    tester,
  ) async {
    await _pumpProfile(tester, guest: false);

    expect(find.text('Сменить пароль'), findsOneWidget);
    expect(find.text('Удалить аккаунт'), findsOneWidget);
    expect(find.text('Политика конфиденциальности'), findsOneWidget);
    expect(find.text('Условия использования'), findsOneWidget);
    expect(find.text('help@food.dev · +77010000000'), findsOneWidget);
  });

  testWidgets('a table guest sees only the legal rows', (tester) async {
    await _pumpProfile(tester, guest: true);

    expect(find.text('Сменить пароль'), findsNothing);
    expect(find.text('Удалить аккаунт'), findsNothing);
    expect(find.text('Политика конфиденциальности'), findsOneWidget);
    expect(find.text('Условия использования'), findsOneWidget);
    expect(find.text('Поддержка'), findsOneWidget);
  });

  testWidgets('deleting asks for the password before it can go ahead', (
    tester,
  ) async {
    await _pumpProfile(tester, guest: false);

    await tester.tap(find.text('Удалить аккаунт'));
    await tester.pump(const Duration(milliseconds: 400));

    final delete = find.widgetWithText(FilledButton, 'Удалить');
    expect(tester.widget<FilledButton>(delete).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'secret123');
    await tester.pump();
    expect(tester.widget<FilledButton>(delete).onPressed, isNotNull);
  });
}
