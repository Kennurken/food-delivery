import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Phone-width column on a warm stage (web/desktop). Matches SwiggyUI's
/// constrained storefront instead of stretching inputs to 1920px.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, this.fullBleed = false});

  static const maxWidth = 560.0;

  final Widget child;
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    if (fullBleed) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, maxWidth);
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: height,
              child: ClipRect(child: child),
            ),
          ),
        );
      },
    );
  }
}
