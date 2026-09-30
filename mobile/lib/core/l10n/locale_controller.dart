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

/// The UI language as the server spells it, for texts it writes on our behalf
/// (push notifications): the in-app choice, else the first of the device's
/// preferred languages we translate, else Russian.
String serverLanguage(Locale? chosen, Iterable<Locale> device) {
  if (chosen != null &&
      LocaleController._supported.contains(chosen.languageCode)) {
    return chosen.languageCode;
  }
  for (final locale in device) {
    if (LocaleController._supported.contains(locale.languageCode)) {
      return locale.languageCode;
    }
  }
  return 'ru';
}
