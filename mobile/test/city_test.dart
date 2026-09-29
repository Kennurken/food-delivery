import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';

import 'package:food_delivery/features/restaurants/domain/city.dart';
import 'package:food_delivery/features/restaurants/domain/restaurant.dart';
import 'package:food_delivery/features/restaurants/data/restaurant_repository.dart';
import 'package:food_delivery/features/restaurants/data/city_choice.dart';
import 'package:food_delivery/features/restaurants/presentation/city_picker.dart';
import 'package:food_delivery/features/restaurants/presentation/home_screen.dart';
import 'package:food_delivery/core/l10n/l10n.dart';

/// Fake storage that mimics FlutterSecureStorage with an in-memory map.
class _FakeStorage extends Fake implements FlutterSecureStorage {
  _FakeStorage([Map<String, String>? initial]) : _map = initial ?? {};

  final Map<String, String> _map;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _map[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _map.remove(key);
  }
}

void main() {
  group('City', () {
    test('fromJson parses slug, name, lat, lng', () {
      final json = {
        'slug': 'almaty',
        'name': 'Алматы',
        'lat': 43.2389,
        'lng': 76.8897,
      };
      final city = City.fromJson(json);
      expect(city.slug, 'almaty');
      expect(city.name, 'Алматы');
      expect(city.lat, 43.2389);
      expect(city.lng, 76.8897);
    });

    test('fromJson tolerates null lat/lng', () {
      final json = {
        'slug': 'astana',
        'name': 'Астана',
        'lat': null,
        'lng': null,
      };
      final city = City.fromJson(json);
      expect(city.slug, 'astana');
      expect(city.name, 'Астана');
      expect(city.lat, isNull);
      expect(city.lng, isNull);
    });
  });

  group('Restaurant', () {
    test('fromJson reads city_slug and city_name', () {
      final json = {
        'id': 1,
        'name': 'Test',
        'cuisine': 'Kazakh',
        'rating': 4.5,
        'delivery_fee': 300,
        'delivery_time_min': 30,
        'is_open': true,
        'city_slug': 'almaty',
        'city_name': 'Алматы',
      };
      final r = Restaurant.fromJson(json);
      expect(r.citySlug, 'almaty');
      expect(r.cityName, 'Алматы');
    });

    test('fromJson leaves city fields null when absent', () {
      final json = {
        'id': 1,
        'name': 'Test',
        'cuisine': 'Kazakh',
        'rating': 4.5,
        'delivery_fee': 300,
        'delivery_time_min': 30,
        'is_open': true,
      };
      final r = Restaurant.fromJson(json);
      expect(r.citySlug, isNull);
      expect(r.cityName, isNull);
    });
  });

  group('RestaurantRepository.list', () {
    late Dio dio;
    late RestaurantRepository repo;
    RequestOptions? captured;

    setUp(() {
      dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response(
                requestOptions: options,
                data: <dynamic>[],
                statusCode: 200,
              ),
            );
          },
        ),
      );
      repo = RestaurantRepository(dio);
    });

    test('list(city: "astana") sends city=astana', () async {
      await repo.list(city: 'astana');
      expect(captured!.queryParameters['city'], 'astana');
    });

    test('list() sends no city param', () async {
      await repo.list();
      expect(captured!.queryParameters.containsKey('city'), isFalse);
    });
  });

  group('CityChoice', () {
    test('set("astana") updates state and writes key', () async {
      final storage = _FakeStorage();
      final container = ProviderContainer(
        overrides: [cityStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(cityChoiceProvider.notifier);
      await notifier.set('astana');

      expect(container.read(cityChoiceProvider), 'astana');
      expect(storage._map['city_slug'], 'astana');
    });

    test('set(null) deletes key', () async {
      final storage = _FakeStorage({'city_slug': 'almaty'});
      final container = ProviderContainer(
        overrides: [cityStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      // Trigger build + _restore first
      container.read(cityChoiceProvider);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(cityChoiceProvider.notifier);
      await notifier.set(null);

      expect(container.read(cityChoiceProvider), isNull);
      expect(storage._map.containsKey('city_slug'), isFalse);
    });

    test('"all cities" picked while the stored city loads is kept', () async {
      final storage = _FakeStorage({'city_slug': 'almaty'});
      final container = ProviderContainer(
        overrides: [cityStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      // Pick before the stored value has had a chance to arrive.
      container.read(cityChoiceProvider);
      await container.read(cityChoiceProvider.notifier).set(null);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(cityChoiceProvider), isNull);
      expect(storage._map.containsKey('city_slug'), isFalse);
    });

    test('value already in storage is restored on first read', () async {
      final storage = _FakeStorage({'city_slug': 'almaty'});
      final container = ProviderContainer(
        overrides: [cityStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      // Trigger build + _restore
      container.read(cityChoiceProvider);
      // Let the unawaited _restore complete
      await Future<void>.delayed(Duration.zero);

      expect(container.read(cityChoiceProvider), 'almaty');
    });
  });

  group('restaurantsProvider', () {
    Future<Map<String, dynamic>> askedWith(String? stored) async {
      Map<String, dynamic>? asked;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              asked = options.queryParameters;
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: <dynamic>[],
                  statusCode: 200,
                ),
              );
            },
          ),
        );
      final container = ProviderContainer(
        overrides: [
          cityStorageProvider.overrideWithValue(
            _FakeStorage({'city_slug': ?stored}),
          ),
          restaurantRepositoryProvider.overrideWithValue(
            RestaurantRepository(dio),
          ),
          citiesProvider.overrideWith(
            (ref) async => const [
              City(slug: 'almaty', name: 'Алматы'),
              City(slug: 'astana', name: 'Астана'),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(cityChoiceProvider);
      await Future<void>.delayed(Duration.zero);
      await container.read(restaurantsProvider.future);
      return asked!;
    }

    test('asks for the chosen city', () async {
      expect((await askedWith('astana'))['city'], 'astana');
    });

    test('a remembered city that was switched off means every city', () async {
      expect((await askedWith('oral')).containsKey('city'), isFalse);
    });

    test('no choice means every city', () async {
      expect((await askedWith(null)).containsKey('city'), isFalse);
    });
  });

  group('HomeTitle', () {
    testWidgets('fits a 320px app bar with a long name and city', (
      tester,
    ) async {
      tester.view.physicalSize =
          const Size(320, 640) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            citiesProvider.overrideWith(
              (ref) async => const [
                City(slug: 'ust-kamenogorsk', name: 'Усть-Каменогорск'),
              ],
            ),
            cityStorageProvider.overrideWithValue(
              _FakeStorage({'city_slug': 'ust-kamenogorsk'}),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            locale: const Locale('ru'),
            home: Scaffold(
              appBar: AppBar(
                title: const HomeTitle(
                  greeting: 'Добрый вечер',
                  name: 'Константинопольский',
                ),
                actions: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // An overflow is thrown as an error in tests; getting here means it fits.
      expect(find.text('Усть-Каменогорск'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a guest sees just the city', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            citiesProvider.overrideWith((ref) async => const <City>[]),
            cityStorageProvider.overrideWithValue(_FakeStorage()),
          ],
          child: MaterialApp(
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            locale: const Locale('ru'),
            home: Scaffold(
              appBar: AppBar(
                title: const HomeTitle(greeting: 'Привет', name: ''),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Все города'), findsOneWidget);
    });
  });

  group('CityPickerSheet widget', () {
    testWidgets('shows all cities and selection works', (tester) async {
      final storage = _FakeStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            citiesProvider.overrideWith(
              (ref) async => [
                City(slug: 'almaty', name: 'Алматы'),
                City(slug: 'astana', name: 'Астана'),
              ],
            ),
            cityStorageProvider.overrideWithValue(storage),
          ],
          child: MaterialApp(
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            locale: const Locale('ru'),
            home: Scaffold(body: CityPickerSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check initial content
      expect(find.text('Все города'), findsOneWidget);
      expect(find.text('Алматы'), findsOneWidget);
      expect(find.text('Астана'), findsOneWidget);

      // Tap "Астана"
      await tester.tap(find.text('Астана'));
      await tester.pumpAndSettle();

      // Verify choice was set - get container from ProviderScope directly
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(container.read(cityChoiceProvider), 'astana');
    });
  });
}
