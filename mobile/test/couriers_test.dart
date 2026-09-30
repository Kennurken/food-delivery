import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/admin/data/couriers_repository.dart';

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
  test(
    'only the venue\'s active couriers are listed among its staff',
    () async {
      final repo = CouriersRepository(
        _dio(
          [],
          (_) => [
            {
              'user_id': 1,
              'email': 'a@x.kz',
              'name': 'Aidos',
              'role': 'delivery_courier',
              'is_active': true,
            },
            {
              'user_id': 2,
              'email': 'b@x.kz',
              'name': 'Bota',
              'role': 'manager',
              'is_active': true,
            },
            {
              'user_id': 3,
              'email': 'c@x.kz',
              'name': 'Chyngys',
              'role': 'delivery_courier',
              'is_active': false,
            },
          ],
        ),
      );

      final list = await repo.list(5);

      expect(list.map((c) => c.userId), [1]);
    },
  );

  test('hiring posts the courier role and the trimmed email', () async {
    final log = <RequestOptions>[];
    await CouriersRepository(_dio(log, (_) => {})).add(5, '  a@x.kz ');

    expect(log.single.path, '/api/v1/admin/restaurants/5/staff');
    expect(log.single.data, {'email': 'a@x.kz', 'role': 'delivery_courier'});
  });

  test('letting one go deletes the membership', () async {
    final log = <RequestOptions>[];
    await CouriersRepository(_dio(log, (_) => {})).remove(5, 9);

    expect(
      (log.single.method, log.single.path),
      ('DELETE', '/api/v1/admin/restaurants/5/staff/9'),
    );
  });
}
