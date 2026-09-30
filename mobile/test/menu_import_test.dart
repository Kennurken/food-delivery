import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/admin/data/menu_import_repository.dart';

void main() {
  test('a preview is asked for with dry_run and read back', () async {
    final log = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            log.add(o);
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: {
                  'applied': false,
                  'created': 1,
                  'updated': 0,
                  'errors': 1,
                  'rows': [
                    {
                      'line': 1,
                      'name': 'Плов',
                      'price': 2500,
                      'category': 'Горячее',
                      'action': 'create',
                      'error': null,
                    },
                    {
                      'line': 2,
                      'name': 'Суп',
                      'price': null,
                      'category': 'Меню',
                      'action': 'error',
                      'error': 'bad_price',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

    final result = await MenuImportRepository(dio)
        .run(4, 'Плов\t2500\nСуп\tx', dryRun: true);

    expect(log.single.path, '/api/v1/admin/restaurants/4/menu/import');
    expect(log.single.data, {'text': 'Плов\t2500\nСуп\tx', 'dry_run': true});
    expect((result.created, result.errors, result.applied), (1, 1, false));
    expect(result.rows[1].error, 'bad_price');
    expect(result.rows[1].price, isNull);
  });
}
