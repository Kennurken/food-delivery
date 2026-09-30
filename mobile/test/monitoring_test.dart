import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/admin/data/admin_repository.dart';

void main() {
  test('the test error goes to the platform endpoint', () async {
    final log = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            log.add(o);
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 202,
                data: {'event_id': 'abc'},
              ),
            );
          },
        ),
      );

    final id = await AdminRepository(dio).sendTestError();

    expect(id, 'abc');
    expect(
      (log.single.method, log.single.path),
      ('POST', '/api/v1/platform/monitoring/test'),
    );
  });
}
