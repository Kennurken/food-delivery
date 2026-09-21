import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/sliding_bottom_nav.dart';

class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final hideNav =
        path.startsWith('/restaurants/') ||
        path == '/cart' ||
        (path.startsWith('/orders/') && path != '/orders');

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: hideNav
          ? null
          : SlidingBottomNav(
              index: navigationShell.currentIndex,
              onTap: (i) => navigationShell.goBranch(
                i,
                initialLocation: i == navigationShell.currentIndex,
              ),
            ),
    );
  }
}
