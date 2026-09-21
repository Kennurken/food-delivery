import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// `null` means follow the device locale.
class LocaleController extends AsyncNotifier<Locale?> {
  static const _key = 'app_locale';
  static const _supported = ['en', 'ru', 'kk'];

  @override
  Future<Locale?> build() async {
    final code = await const FlutterSecureStorage().read(key: _key);
    if (code == null || !_supported.contains(code)) return null;
    return Locale(code);
  }

  Future<void> setLocale(Locale? locale) async {
    const storage = FlutterSecureStorage();
    if (locale == null) {
      await storage.delete(key: _key);
    } else {
      await storage.write(key: _key, value: locale.languageCode);
    }
    state = AsyncData(locale);
  }
}

final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, Locale?>(LocaleController.new);
