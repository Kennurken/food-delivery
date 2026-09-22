import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/l10n.dart';
import 'core/l10n/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'features/notifications/live_events_listener.dart';

class FoodDeliveryApp extends ConsumerWidget {
  const FoodDeliveryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider).value;
    return MaterialApp.router(
      title: 'Food Delivery',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: locale,
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => _RouteAwareShell(
        delegate: ref.read(routerProvider).routerDelegate,
        child: LiveEventsListener(child: child!),
      ),
    );
  }
}

/// Picks the shell chrome from the current route.
///
/// A plain [ListenableBuilder] on the delegate asserts on the first frame:
/// [AppShell] lays out through a LayoutBuilder, the Router mounts inside that
/// layout callback, and restoring the initial route notifies listeners while
/// the frame is still building. Reading the path is always safe — it is the
/// *rebuild* that has to wait for the frame to finish.
class _RouteAwareShell extends StatefulWidget {
  const _RouteAwareShell({required this.delegate, required this.child});

  final GoRouterDelegate delegate;
  final Widget child;

  @override
  State<_RouteAwareShell> createState() => _RouteAwareShellState();
}

class _RouteAwareShellState extends State<_RouteAwareShell> {
  @override
  void initState() {
    super.initState();
    widget.delegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    widget.delegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    final building =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (building) {
      // This build already reads the new path; just repaint after the frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.delegate.currentConfiguration.uri.path;
    return AppShell(
      fullBleed:
          path.contains('/floor') ||
          path.contains('/kitchen') ||
          path.contains('/map'),
      child: widget.child,
    );
  }
}
