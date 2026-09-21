import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Slowly drifting radial blobs (animate-ui "Gradient background"). Cheap: 3 circles, one ticker.
class AnimatedGradient extends StatefulWidget {
  const AnimatedGradient({super.key, required this.colors, this.child});

  final List<Color> colors;
  final Widget? child;

  @override
  State<AnimatedGradient> createState() => _AnimatedGradientState();
}

class _AnimatedGradientState extends State<AnimatedGradient>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => CustomPaint(
        painter: _BlobPainter(_ctrl.value, widget.colors),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.t, this.colors);

  final double t;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    final r = size.shortestSide * 0.7;
    for (var i = 0; i < colors.length; i++) {
      final phase = a + i * 2.1;
      final c = Offset(
        size.width * (0.5 + 0.35 * math.cos(phase)),
        size.height * (0.4 + 0.3 * math.sin(phase * 0.8)),
      );
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[i].withValues(alpha: 0.55),
            colors[i].withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t;
}
