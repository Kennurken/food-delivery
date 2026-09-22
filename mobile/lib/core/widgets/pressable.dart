import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Scales on hover (1.05) and press (0.95) — animate-ui Button.
/// Reduced-motion users get the tap with no scale.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = Motion.tapScale,
    this.hoverScale = Motion.hoverScale,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final double hoverScale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _hover = false;
  var _pressed = false;

  double get _target {
    if (Motion.reduced(context)) return 1;
    if (_pressed) return widget.scale;
    if (_hover) return widget.hoverScale;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: widget.onTap != null,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _target,
            duration: Motion.of(context, Motion.fast),
            curve: _pressed ? Curves.easeOut : Motion.pop,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
