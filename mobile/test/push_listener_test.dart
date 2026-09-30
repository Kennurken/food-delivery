import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:food_delivery/core/l10n/l10n.dart';
import 'package:food_delivery/core/l10n/locale_controller.dart';
import 'package:food_delivery/core/router/app_router.dart';
import 'package:food_delivery/core/widgets/root_messenger.dart';
import 'package:food_delivery/features/auth/domain/user.dart';
import 'package:food_delivery/features/auth/presentation/auth_controller.dart';
import 'package:food_delivery/features/notifications/device_repository.dart';
import 'package:food_delivery/features/notifications/push_listener.dart';
import 'package:food_delivery/features/notifications/push_route.dart';

class _SignedIn extends AuthController {
  @override
  Future<User?> build() async => const User(
    id: 3,
    email: 'user@food.dev',
    name: 'Айгерим',
    role: 'customer',
  );
}

class _Locale extends LocaleController {
  @override
  Future<Locale?> build() async => const Locale('ru');
}

GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    for (final path in ['/', '/splash', '/orders/:id', '/chat/:id'])
      GoRoute(
        path: path,
        builder: (_, s) => Scaffold(body: Text('at ${s.uri.path}')),
      ),
  ],
);

class _Harness {
  _Harness({String initial = '/'}) : router = _router(initial);

  final opened = StreamController<Map<String, dynamic>>();
  final foreground = StreamController<PushMessage>();
  final devices = <RequestOptions>[];
  final GoRouter router;
  Map<String, dynamic>? launch;

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            devices.add(o);
            h.resolve(Response(requestOptions: o, statusCode: 204));
          },
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authControllerProvider.overrideWith(_SignedIn.new),
          localeControllerProvider.overrideWith(_Locale.new),
          routerProvider.overrideWithValue(router),
          deviceRepositoryProvider.overrideWithValue(
            DeviceRepository(dio, language: () async => 'kk'),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          scaffoldMessengerKey: rootMessengerKey,
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          locale: const Locale('ru'),
          builder: (_, child) => PushListener(
            opened: opened.stream,
            foreground: foreground.stream,
            launchData: () async => launch,
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(PushListener)));
  }
}

void main() {
  // The device token and the language choice both live in secure storage.
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('tapping a push in the background opens its order', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    expect(find.text('at /'), findsOneWidget);

    h.opened.add({'order_id': '42', 'status': 'preparing'});
    await tester.pumpAndSettle();

    expect(find.text('at /orders/42'), findsOneWidget);
    // Pushed, so back returns to what the user was doing.
    expect(h.router.canPop(), isTrue);
  });

  testWidgets('the push that launched the app is followed once signed in', (
    tester,
  ) async {
    final h = _Harness()..launch = {'order_id': '7', 'cause': 'chat'};
    await h.pump(tester);

    expect(find.text('at /chat/7'), findsOneWidget);
  });

  testWidgets('a launch push waits for the splash screen to hand over', (
    tester,
  ) async {
    final h = _Harness(initial: '/splash')
      ..launch = {'order_id': '7', 'cause': 'chat'};
    await h.pump(tester);
    // Stacking the chat on the splash would be lost to the redirect home.
    expect(find.text('at /splash'), findsOneWidget);

    h.router.go('/');
    await tester.pumpAndSettle();

    expect(find.text('at /chat/7'), findsOneWidget);
    expect(h.router.canPop(), isTrue);
  });

  testWidgets('an escalation in the foreground offers to open the chat', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);

    h.foreground.add(
      const PushMessage(
        data: {'order_id': '42', 'cause': 'escalation'},
        title: 'Заказ #42: нужен менеджер',
        body: 'Асель просит подключиться к чату',
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Заказ #42: нужен менеджер'), findsOneWidget);
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.text('at /chat/42'), findsOneWidget);
  });

  testWidgets('a status push in the foreground is left to the live socket', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);

    h.foreground.add(
      const PushMessage(
        data: {'order_id': '42', 'cause': 'status'},
        title: 'Заказ #42',
        body: 'Готовится',
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('switching the language re-registers the device', (tester) async {
    final h = _Harness();
    final container = await h.pump(tester);
    expect(h.devices, isEmpty);

    await container
        .read(localeControllerProvider.notifier)
        .setLocale(const Locale('kk'));
    await tester.pumpAndSettle();

    expect(h.devices, hasLength(1));
    expect((h.devices.single.data as Map)['lang'], 'kk');
  });
}
