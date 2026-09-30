import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/courier/data/shift_repository.dart';

Dio _dio(
  List<RequestOptions> log,
  Response<dynamic> Function(RequestOptions) answer,
) => Dio()
  ..interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        log.add(options);
        final r = answer(options);
        if ((r.statusCode ?? 200) >= 400) {
          handler.reject(DioException(requestOptions: options, response: r));
        } else {
          handler.resolve(r);
        }
      },
    ),
  );

ProviderContainer _container(Dio dio) {
  final c = ProviderContainer(
    overrides: [
      shiftRepositoryProvider.overrideWithValue(ShiftRepository(dio)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('reads the shift from the server', () async {
    final log = <RequestOptions>[];
    final c = _container(
      _dio(
        log,
        (o) => Response(
          requestOptions: o,
          data: {'on_shift': false},
          statusCode: 200,
        ),
      ),
    );

    expect(await c.read(shiftProvider.future), isFalse);
    expect(log.single.path, '/api/v1/me/shift');
  });

  test(
    'going off posts the choice and shows what the server accepted',
    () async {
      final log = <RequestOptions>[];
      final c = _container(
        _dio(log, (o) {
          final on = o.method == 'POST' ? (o.data as Map)['on'] as bool : true;
          return Response(
            requestOptions: o,
            data: {'on_shift': on},
            statusCode: 200,
          );
        }),
      );
      await c.read(shiftProvider.future);

      await c.read(shiftProvider.notifier).set(false);

      expect(c.read(shiftProvider).value, isFalse);
      expect(log.last.method, 'POST');
      expect(log.last.data, {'on': false});
    },
  );

  test(
    'a refusal leaves the switch where it was and reaches the caller',
    () async {
      final c = _container(
        _dio([], (o) {
          if (o.method == 'POST') {
            return Response(
              requestOptions: o,
              statusCode: 409,
              data: {'detail': 'busy'},
            );
          }
          return Response(
            requestOptions: o,
            data: {'on_shift': true},
            statusCode: 200,
          );
        }),
      );
      await c.read(shiftProvider.future);

      await expectLater(
        c.read(shiftProvider.notifier).set(false),
        throwsA(isA<DioException>()),
      );

      expect(c.read(shiftProvider).value, isTrue);
    },
  );
}
