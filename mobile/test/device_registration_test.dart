import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/api/api_client.dart';
import 'package:food_delivery/core/l10n/locale_controller.dart';
import 'package:food_delivery/features/notifications/device_repository.dart';

Dio _dio(List<RequestOptions> log) => Dio()
  ..interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        log.add(options);
        handler.resolve(Response(requestOptions: options, statusCode: 204));
      },
    ),
  );

class _Chosen extends LocaleController {
  _Chosen(this.locale);

  final Locale? locale;

  @override
  Future<Locale?> build() async => locale;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('registration tells the server which language to push in', () async {
    final log = <RequestOptions>[];
    final repo = DeviceRepository(_dio(log), language: () async => 'kk');

    await repo.sync();

    expect(log, hasLength(1));
    expect(log.single.method, 'PUT');
    expect(log.single.path, '/api/v1/me/devices');
    final body = log.single.data as Map<String, dynamic>;
    expect(body['lang'], 'kk');
    expect(body['platform'], isIn(['android', 'ios', 'web']));
    // No Firebase in tests: the device falls back to its minted local id.
    expect((body['token'] as String).length, greaterThanOrEqualTo(8));
  });

  test('the language picked in the app is the one registered', () async {
    final log = <RequestOptions>[];
    final container = ProviderContainer(
      overrides: <Override>[
        dioProvider.overrideWithValue(_dio(log)),
        localeControllerProvider.overrideWith(
          () => _Chosen(const Locale('kk')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(deviceRepositoryProvider).sync();

    expect((log.single.data as Map)['lang'], 'kk');
  });

  group('serverLanguage', () {
    test('the in-app choice wins over the device', () {
      expect(
        serverLanguage(const Locale('en'), const [Locale('kk', 'KZ')]),
        'en',
      );
    });

    test('following the device takes its first language we translate', () {
      expect(
        serverLanguage(null, const [Locale('de'), Locale('kk', 'KZ')]),
        'kk',
      );
      expect(serverLanguage(null, const [Locale('ru', 'RU')]), 'ru');
    });

    test('a device in none of our languages gets Russian', () {
      expect(serverLanguage(null, const [Locale('de'), Locale('fr')]), 'ru');
      expect(serverLanguage(null, const []), 'ru');
    });
  });
}
