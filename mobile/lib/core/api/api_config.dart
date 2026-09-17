import 'dart:io';

class ApiConfig {
  ApiConfig._();

  /// Android emulator maps host loopback to 10.0.2.2.
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';
  }
}
