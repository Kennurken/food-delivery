import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The city the diner is browsing. null means every city — what the app did
/// before cities existed, and still the right answer until they pick one.
/// Remembered across launches: nobody wants to pick their city every morning.
class CityChoice extends Notifier<String?> {
  static const _key = 'city_slug';

  /// Whether the diner has chosen in this session. "All cities" is a choice
  /// too, and it is also null — so state alone can't say whether the stored
  /// value arrived too late to matter.
  var _picked = false;

  @override
  String? build() {
    unawaited(_restore());
    return null;
  }

  Future<void> _restore() async {
    final saved = await ref.read(cityStorageProvider).read(key: _key);
    // A pick made while the read was in flight wins over the stored one.
    if (saved != null && !_picked) state = saved;
  }

  Future<void> set(String? slug) async {
    _picked = true;
    state = slug;
    final storage = ref.read(cityStorageProvider);
    if (slug == null) {
      await storage.delete(key: _key);
    } else {
      await storage.write(key: _key, value: slug);
    }
  }
}

final cityStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final cityChoiceProvider = NotifierProvider<CityChoice, String?>(
  CityChoice.new,
);
