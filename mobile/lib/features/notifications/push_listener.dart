import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/root_messenger.dart';
import '../auth/domain/user.dart';
import '../auth/presentation/auth_controller.dart';
import 'device_repository.dart';
import 'fcm.dart';
import 'push_route.dart';

/// What happens to a push once it reaches the app.
///
/// A tap opens the screen the push is about, whether the app was in the
/// background or launched by the tap. A push arriving while the app is open
/// becomes a SnackBar with an "Open" action. And a change of UI language
/// re-registers the device, so the server writes the next push in it.
class PushListener extends ConsumerStatefulWidget {
  const PushListener({
    super.key,
    required this.child,
    this.opened,
    this.foreground,
    this.launchData,
  });

  final Widget child;

  /// Sources of pushes; [Fcm]'s by default, which stay silent without
  /// Firebase. Tests pass their own.
  final Stream<Map<String, dynamic>>? opened;
  final Stream<PushMessage>? foreground;
  final Future<Map<String, dynamic>?> Function()? launchData;

  @override
  ConsumerState<PushListener> createState() => _PushListenerState();
}

class _PushListenerState extends ConsumerState<PushListener> {
  final _subs = <StreamSubscription<Object?>>[];
  var _launchChecked = false;
  GoRouterDelegate? _waitingOn;
  VoidCallback? _waiting;

  @override
  void initState() {
    super.initState();
    _subs
      ..add((widget.opened ?? Fcm.onOpened).listen(_onOpened))
      ..add((widget.foreground ?? Fcm.onForeground).listen(_onForeground));
    // The launch tap is only followed once somebody is signed in: before
    // that, the router would park the route behind the login screen.
    ref.listenManual(authControllerProvider, (_, next) {
      if (next.value != null) unawaited(_checkLaunch());
    }, fireImmediately: true);
    ref.listenManual(localeControllerProvider, (prev, next) {
      // Only a real switch in the picker. Reading the saved choice at start
      // is not one, and signing in registers with the current language.
      if (prev == null || !prev.hasValue || !next.hasValue) return;
      if (prev.value == next.value) return;
      if (ref.read(authControllerProvider).value == null) return;
      unawaited(ref.read(deviceRepositoryProvider).sync());
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _stopWaiting();
    super.dispose();
  }

  Future<void> _checkLaunch() async {
    if (_launchChecked) return;
    _launchChecked = true;
    final data = await (widget.launchData ?? Fcm.takeLaunchData)();
    if (data == null || !mounted) return;
    final route = routeForPush(data);
    if (route != null) _openWhenSettled(route);
  }

  /// At launch the user is known while the router still stands on the splash
  /// screen; a page stacked on that is thrown away by the redirect to the
  /// role's home that follows. So wait for that home first.
  void _openWhenSettled(String route) {
    final delegate = ref.read(routerProvider).routerDelegate;
    bool settled() {
      final path = delegate.currentConfiguration.uri.path;
      return path.isNotEmpty &&
          path != '/splash' &&
          path != '/login' &&
          path != '/register';
    }

    if (settled()) {
      _open(route);
      return;
    }
    _stopWaiting();
    void check() {
      if (!settled()) return;
      _stopWaiting();
      // The redirect's own frame is still being built; stack after it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(route);
      });
    }

    _waitingOn = delegate..addListener(check);
    _waiting = check;
  }

  void _stopWaiting() {
    final listener = _waiting;
    if (listener != null) _waitingOn?.removeListener(listener);
    _waitingOn = null;
    _waiting = null;
  }

  void _onOpened(Map<String, dynamic> data) {
    final route = routeForPush(data);
    if (route != null) _open(route);
  }

  void _open(String route) {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;
    openPushRoute(ref.read(routerProvider), user, route);
  }

  void _onForeground(PushMessage message) {
    if (!showsInForeground(message.data)) return;
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;
    final router = ref.read(routerProvider);
    final route = routeForPush(message.data);
    // Already looking at it: a manager called into the chat they have open.
    if (route != null && _isShowing(router, route)) return;
    final title = message.title?.trim() ?? '';
    final body = message.body?.trim() ?? '';
    if (title.isEmpty && body.isEmpty) return;
    final canOpen = route != null && roleAllows(user, Uri.parse(route).path);
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (body.isNotEmpty) Text(body),
          ],
        ),
        action: canOpen
            ? SnackBarAction(
                label: context.l10n.pushOpen,
                onPressed: () => _open(route),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

bool _isShowing(GoRouter router, String route) {
  final here = router.routerDelegate.currentConfiguration.uri;
  final target = Uri.parse(route);
  return here.path == target.path && here.query == target.query;
}

/// Opens [route] for a push. It goes on top of whatever the user was doing,
/// so back returns there; the admin home is switched in place instead of
/// stacking a second copy of it. A route [user]'s role can't stand on (an
/// order page for a courier) opens nothing: the app just comes to the front.
void openPushRoute(GoRouter router, User user, String route) {
  final path = Uri.parse(route).path;
  if (!roleAllows(user, path) || _isShowing(router, route)) return;
  if (path == '/admin') {
    router.go(route);
  } else {
    unawaited(router.push<void>(route));
  }
}
