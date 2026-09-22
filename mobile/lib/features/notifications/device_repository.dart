import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';

/// Local device id sent to PUT /me/devices. Not an FCM token until a key exists.
class DeviceRepository {
  DeviceRepository(this._dio, [this._storage = const FlutterSecureStorage()]);

  final Dio _dio;
  final FlutterSecureStorage _storage;
  static const _key = 'device_token';

  String get platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      _ => 'android',
    };
  }

  Future<String> token() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.length >= 8) return existing;
    final rnd = Random.secure();
    final minted = List.generate(
      32,
      (_) => rnd.nextInt(16).toRadixString(16),
    ).join();
    await _storage.write(key: _key, value: minted);
    return minted;
  }

  Future<void> sync() async {
    try {
      await _dio.put(
        '/api/v1/me/devices',
        data: {'token': await token(), 'platform': platform},
      );
    } catch (_) {}
  }

  Future<void> forget() async {
    try {
      final t = await _storage.read(key: _key);
      if (t == null || t.length < 8) return;
      await _dio.delete('/api/v1/me/devices', queryParameters: {'token': t});
    } catch (_) {}
  }
}

final deviceRepositoryProvider = Provider(
  (ref) => DeviceRepository(ref.watch(dioProvider)),
);
