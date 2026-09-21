import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  /// Set at build time: --dart-define=API_URL=https://food-delivery-api.fly.dev
  static const _fromEnv = String.fromEnvironment('API_URL');

  /// Release builds must point at a real server; debug falls back to the
  /// local backend (Android emulator maps host loopback to 10.0.2.2).
  static String get baseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    assert(
      kDebugMode,
      'Release build without API_URL — pass --dart-define=API_URL=...',
    );
    return Platform.isAndroid
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }
}
