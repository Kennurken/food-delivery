import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  /// Set at build time: `--dart-define=API_URL=https://food-delivery-api.vercel.app`
  static const _fromEnv = String.fromEnvironment('API_URL');

  /// Cloud / release: pass API_URL. Debug: emulator, localhost, or same origin on web.
  static String get baseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
        return 'http://127.0.0.1:8000';
      }
      return origin;
    }
    assert(
      kDebugMode,
      'Release build without API_URL — pass --dart-define=API_URL=...',
    );
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }
}
