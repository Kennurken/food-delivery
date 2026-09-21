import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Scales its child to [Motion.tapScale] while pressed, springs back on release.
/// Wrap any tappable card/button — mirrors animate-ui `whileTap={{ scale: 0.95 }}`.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = Motion.tapScale,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: Motion.fast,
    reverseDuration: Motion.normal,
  );
  late final _scale = Tween(begin: 1.0, end: widget.scale).animate(
    CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOut,
      reverseCurve: Motion.pop,
    ),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: _ctrl.reverse,
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
