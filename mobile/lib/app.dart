import 'package:flutter/material.dart';
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
      builder: (context, child) {
        final router = ref.read(routerProvider);
        return ListenableBuilder(
          listenable: router.routerDelegate,
          builder: (context, _) {
            final path = router.routerDelegate.currentConfiguration.uri.path;
            return AppShell(
              fullBleed: path.contains('/floor'),
              child: LiveEventsListener(child: child!),
            );
          },
        );
      },
    );
  }
}
