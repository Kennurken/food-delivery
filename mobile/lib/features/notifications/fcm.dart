import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_route.dart';

/// Push through Firebase Cloud Messaging, when this build has it.
///
/// A build without the platform config file (google-services.json /
/// GoogleService-Info.plist) has no Firebase, and everything here quietly does
/// nothing: the app then relies on its live connection while open, exactly as
/// it did before push existed. Not on the web, which has no service worker
/// here. Tests never call [init], so every getter below stays inert there.
class Fcm {
  /// Resolves once Firebase is up (true) or known to be absent (false). Null
  /// until [init] runs, which is what keeps tests and web away from Firebase.
  static Future<bool>? _app;
  static var _available = false;
  static var _launchTaken = false;

  static bool get available => _available;

  static Future<void> init() async {
    if (kIsWeb || _app != null) return;
    _app = _initApp();
    if (!await _app!) return;
    try {
      // iOS asks; Android 13+ is asked by LocalPush already. Refusing is fine:
      // the token still registers and the OS just won't show the banner.
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
  }

  static Future<bool> _initApp() async {
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  /// main() starts [init] without awaiting it, so anything that runs early
  /// (the first device sync, the listeners below) waits here instead of
  /// deciding "no Firebase" while it is still starting.
  static Future<bool> _ready() => _app ?? Future.value(false);

  /// This device's FCM token, or null when there is no Firebase or the OS
  /// hasn't issued one yet (iOS gives none until APNs is set up).
  static Future<String?> token() async {
    if (!await _ready()) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Fires when Google rotates the token; the caller re-registers it.
  static Stream<String> get onRefresh =>
      _afterReady(() => FirebaseMessaging.instance.onTokenRefresh);

  /// Data of each notification tapped while the app was in the background.
  static Stream<Map<String, dynamic>> get onOpened =>
      _afterReady(() => FirebaseMessaging.onMessageOpenedApp.map(_data));

  /// Pushes that arrive while the app is in the foreground. The OS shows no
  /// banner for these, so the app decides what to show.
  static Stream<PushMessage> get onForeground => _afterReady(
    () => FirebaseMessaging.onMessage.map(
      (m) => PushMessage(
        data: _data(m),
        title: m.notification?.title,
        body: m.notification?.body,
      ),
    ),
  );

  /// Data of the notification whose tap launched the app from terminated, at
  /// most once per process: signing out and back in must not replay it.
  static Future<Map<String, dynamic>?> takeLaunchData() async {
    if (_launchTaken) return null;
    _launchTaken = true;
    if (!await _ready()) return null;
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      return message == null ? null : _data(message);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _data(RemoteMessage m) =>
      Map<String, dynamic>.of(m.data);

  static Stream<T> _afterReady<T>(Stream<T> Function() open) async* {
    if (!await _ready()) return;
    yield* open();
  }
}

/// Token rotations while a user is signed in, so the server keeps a token that
/// still works.
final fcmRefreshProvider = StreamProvider<String>((ref) => Fcm.onRefresh);
