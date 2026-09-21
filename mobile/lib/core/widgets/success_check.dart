import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Circle draws itself, then the check strokes in (jitter "Loading Spinner: Success").
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({super.key, this.size = 96, this.color});

  final double size;
  final Color? color;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _Painter(_ctrl.value, color),
      ),
    );
  }
}

class _Painter extends CustomPainter {
  _Painter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;

    // 0..0.55 circle, 0.5..1 check
    final circleT = Motion.enter.transform((t / 0.55).clamp(0, 1));
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(paint.strokeWidth);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * circleT, false, paint);

    final checkT = Motion.emphasized.transform(((t - 0.5) / 0.5).clamp(0, 1));
    if (checkT == 0) return;
    final p = Path()
      ..moveTo(size.width * 0.28, size.height * 0.53)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.73, size.height * 0.36);
    for (final m in p.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * checkT), paint);
    }
  }

  @override
  bool shouldRepaint(_Painter old) => old.t != t || old.color != color;
}
