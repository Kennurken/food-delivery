import 'package:dio/dio.dart';

import '../domain/models.dart';

class FloorPlanRepository {
  FloorPlanRepository(this._dio);

  final Dio _dio;

  Future<List<FloorSummary>> list(int restaurantId) async {
    final r = await _dio.get('/api/v1/admin/restaurants/$restaurantId/floors');
    return (r.data as List)
        .map((e) => FloorSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FloorDoc> create(
    int restaurantId, {
    required String name,
    String? template,
  }) async {
    final r = await _dio.post(
      '/api/v1/admin/restaurants/$restaurantId/floors',
      data: {'name': name, 'template': ?template},
    );
    return FloorDoc.fromJson(r.data as Map<String, dynamic>);
  }

  Future<FloorDoc> get(int floorId) async {
    final r = await _dio.get('/api/v1/admin/floors/$floorId');
    return FloorDoc.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> rename(int floorId, String name) async {
    await _dio.patch('/api/v1/admin/floors/$floorId', data: {'name': name});
  }

  Future<void> delete(int floorId) =>
      _dio.delete('/api/v1/admin/floors/$floorId');

  Future<FloorDoc> duplicate(int floorId) async {
    final r = await _dio.post('/api/v1/admin/floors/$floorId/duplicate');
    return FloorDoc.fromJson(r.data as Map<String, dynamic>);
  }

  Future<FloorDoc> save(FloorDoc doc) async {
    final r = await _dio.put(
      '/api/v1/admin/floors/${doc.id}/layout',
      data: {
        'updated_at': doc.updatedAt,
        'zones': doc.zones.map((z) => z.toJson()).toList(),
        'objects': doc.objects.map((o) => o.toJson()).toList(),
      },
    );
    return FloorDoc.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<(int, String, String)>> versions(int floorId) async {
    final r = await _dio.get('/api/v1/admin/floors/$floorId/versions');
    return [
      for (final e in r.data as List)
        (e['id'] as int, e['label'] as String, e['created_at'] as String),
    ];
  }

  Future<FloorDoc> restore(int floorId, int versionId) async {
    final r = await _dio.post(
      '/api/v1/admin/floors/$floorId/versions/$versionId/restore',
    );
    return FloorDoc.fromJson(r.data as Map<String, dynamic>);
  }

  Future<String> tableQr(int floorId, int objectId) async {
    final r = await _dio.get(
      '/api/v1/admin/floors/$floorId/objects/$objectId/qr',
    );
    return r.data['token'] as String;
  }
}
