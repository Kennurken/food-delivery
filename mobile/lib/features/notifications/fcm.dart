import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Push through Firebase Cloud Messaging, when this build has it.
///
/// A build without the platform config file (google-services.json /
/// GoogleService-Info.plist) has no Firebase, and everything here quietly does
/// nothing: the app then relies on its live connection while open, exactly as
/// it did before push existed. Not on the web, which has no service worker
/// here.
class Fcm {
  static var _started = false;
  static var _available = false;

  static bool get available => _available;

  static Future<void> init() async {
    if (kIsWeb || _started) return;
    _started = true;
    try {
      await Firebase.initializeApp();
      _available = true;
      // iOS asks; Android 13+ is asked by LocalPush already. Refusing is fine:
      // the token still registers and the OS just won't show the banner.
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {
      _available = false;
    }
  }

  /// This device's FCM token, or null when there is no Firebase or the OS
  /// hasn't issued one yet (iOS gives none until APNs is set up).
  static Future<String?> token() async {
    if (!_available) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Fires when Google rotates the token; the caller re-registers it.
  static Stream<String> get onRefresh => _available
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream.empty();
}

/// Token rotations while a user is signed in, so the server keeps a token that
/// still works.
final fcmRefreshProvider = StreamProvider<String>((ref) => Fcm.onRefresh);
