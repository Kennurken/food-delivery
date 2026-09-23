import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Icons that draw themselves.
///
/// Hand-authored rather than pulled from an icon service: these ship as code,
/// so they weigh nothing, take the surrounding [IconTheme]'s colour and size
/// like any other icon, and carry no licence to honour. A bought Lottie file
/// can still be dropped in later — see `docs/animated-icons.md` — but nothing
/// in the product depends on one arriving.
///
/// Stroke weight and geometry follow Material's outlined set so these sit next
/// to ordinary [Icon]s without looking like a different family.
enum AnimShape {
  /// Shopping bag: handle draws, body rises.
  bag,

  /// Delivery scooter: wheels turn, body bobs.
  scooter,

  /// Struck-through circle: the ring closes, then the bar sweeps across.
  stop,

  /// Bell: swings twice and settles.
  bell,

  /// Bar chart: columns grow from the baseline.
  chart,

  /// Payment card: slides in, magnetic stripe follows.
  card,

  /// Price tag: tips into place, punch-hole last.
  tag,

  /// Cooking pot: lid lifts and steam rises.
  pot,

  /// Floor grid: cells appear one after another.
  grid,

  /// Plus: rotates a quarter turn as it draws.
  plus,

  /// Wallet with a coin dropping in.
  wallet,

  /// Magnifier sweeping its handle out.
  search,
}

enum AnimPlay {
  /// Runs once when the icon first appears.
  onAppear,

  /// Runs on every tap of the enclosing button, via [AnimIconButton].
  onTap,

  /// Runs forever. Use sparingly — a looping icon in a list is noise.
  loop,
}

/// Draws one of [AnimShape]. Behaves like [Icon]: size and colour come from the
/// ambient [IconTheme] unless given.
class AnimIcon extends StatefulWidget {
  const AnimIcon(
    this.shape, {
    super.key,
    this.size,
    this.color,
    this.play = AnimPlay.onAppear,
    this.duration,
  });

  final AnimShape shape;
  final double? size;
  final Color? color;
  final AnimPlay play;
  final Duration? duration;

  @override
  State<AnimIcon> createState() => AnimIconState();
}

class AnimIconState extends State<AnimIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration ?? Motion.slow,
  );

  var _started = false;

  /// How far through the drawing the icon is, 0 to 1.
  @visibleForTesting
  double get progress => _c.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion is read here, not in initState: an inherited widget is
    // off limits until dependencies are resolved, and MediaQuery is one.
    if (Motion.reduced(context)) {
      _c.stop();
      _c.value = 1;
      return;
    }
    if (_started) return;
    _started = true;
    switch (widget.play) {
      case AnimPlay.loop:
        _c.repeat();
      case AnimPlay.onAppear:
        _c.forward();
      case AnimPlay.onTap:
        // Sits on the finished drawing until something presses it.
        _c.value = 1;
    }
  }

  /// Replays from the start. Called by [AnimIconButton] on tap.
  void replay() {
    if (Motion.reduced(context)) return;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = widget.size ?? theme.size ?? 24;
    final color =
        widget.color ?? theme.color ?? Theme.of(context).colorScheme.onSurface;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.square(size),
          painter: _ShapePainter(
            shape: widget.shape,
            t: Curves.easeOutCubic.transform(_c.value.clamp(0, 1)),
            raw: _c.value,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// An [IconButton] whose icon replays on every press.
class AnimIconButton extends StatefulWidget {
  const AnimIconButton({
    super.key,
    required this.shape,
    required this.onPressed,
    this.tooltip,
    this.size,
    this.color,
  });

  final AnimShape shape;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double? size;
  final Color? color;

  @override
  State<AnimIconButton> createState() => _AnimIconButtonState();
}

class _AnimIconButtonState extends State<AnimIconButton> {
  final _icon = GlobalKey<AnimIconState>();

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: widget.tooltip,
    onPressed: widget.onPressed == null
        ? null
        : () {
            _icon.currentState?.replay();
            widget.onPressed!();
          },
    icon: AnimIcon(
      widget.shape,
      key: _icon,
      size: widget.size,
      color: widget.color,
      play: AnimPlay.onTap,
    ),
  );
}

/// Draws one shape at a given progress straight onto a canvas.
///
/// Public because it is genuinely reusable — anywhere a shape is needed without
/// a widget, such as `tool/render_icons.dart`, which draws the review sheet. A
/// CustomPainter is only correct if it reads right, and no assertion can tell
/// you that; looking at the sheet is how that gets checked.
void paintShape(
  Canvas canvas,
  AnimShape shape,
  double progress,
  double size,
  Color color,
) => _ShapePainter(
  shape: shape,
  t: Curves.easeOutCubic.transform(progress.clamp(0, 1)),
  raw: progress,
  color: color,
).paint(canvas, Size.square(size));

class _ShapePainter extends CustomPainter {
  const _ShapePainter({
    required this.shape,
    required this.t,
    required this.raw,
    required this.color,
  });

  final AnimShape shape;

  /// Eased progress, for drawing.
  final double t;

  /// Linear progress, for anything that must run at a constant rate (wheels).
  final double raw;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          s *
          0.083 // ~2px at 24
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (shape) {
      case AnimShape.bag:
        _bag(canvas, s, stroke);
      case AnimShape.scooter:
        _scooter(canvas, s, stroke, fill);
      case AnimShape.stop:
        _stop(canvas, s, stroke);
      case AnimShape.bell:
        _bell(canvas, s, stroke, fill);
      case AnimShape.chart:
        _chart(canvas, s, stroke);
      case AnimShape.card:
        _card(canvas, s, stroke);
      case AnimShape.tag:
        _tag(canvas, s, stroke, fill);
      case AnimShape.pot:
        _pot(canvas, s, stroke);
      case AnimShape.grid:
        _grid(canvas, s, stroke);
      case AnimShape.plus:
        _plus(canvas, s, stroke);
      case AnimShape.wallet:
        _wallet(canvas, s, stroke, fill);
      case AnimShape.search:
        _search(canvas, s, stroke);
    }
  }

  // Two-phase helper: 0..split maps to the first move, split..1 to the second.
  double _phase(double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  void _bag(Canvas canvas, double s, Paint stroke) {
    final rise = (1 - _phase(0, 0.6)) * s * 0.25;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.18, s * 0.38 + rise, s * 0.64, s * 0.46),
      Radius.circular(s * 0.1),
    );
    canvas.drawRRect(body, stroke);
    // The handle draws itself after the bag has landed.
    final handle = _phase(0.45, 1);
    if (handle > 0) {
      final rect = Rect.fromCircle(
        center: Offset(s * 0.5, s * 0.4 + rise),
        radius: s * 0.15,
      );
      canvas.drawArc(rect, math.pi, math.pi * handle, false, stroke);
    }
  }

  void _scooter(Canvas canvas, double s, Paint stroke, Paint fill) {
    final bob = math.sin(raw * math.pi * 4) * s * 0.015 * (1 - t * 0.5);
    final rear = Offset(s * 0.24, s * 0.72 + bob);
    final front = Offset(s * 0.80, s * 0.72 + bob);
    canvas.drawCircle(rear, s * 0.12, stroke);
    canvas.drawCircle(front, s * 0.12, stroke);
    // Spokes turn at a constant rate; easing them reads as stuttering.
    for (final wheel in [rear, front]) {
      final a = raw * math.pi * 2;
      canvas.drawLine(
        wheel + Offset(math.cos(a), math.sin(a)) * s * 0.07,
        wheel - Offset(math.cos(a), math.sin(a)) * s * 0.07,
        stroke,
      );
    }
    // Seat box, footboard, stem and handlebar — the silhouette that separates
    // a scooter from two circles with a line between them.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.14, s * 0.44 + bob, s * 0.30, s * 0.13),
        Radius.circular(s * 0.05),
      ),
      stroke,
    );
    final frame = Path()
      ..moveTo(s * 0.28, s * 0.68 + bob)
      ..lineTo(s * 0.66, s * 0.68 + bob)
      ..lineTo(s * 0.80, s * 0.36 + bob)
      ..moveTo(s * 0.70, s * 0.34 + bob)
      ..lineTo(s * 0.90, s * 0.34 + bob);
    canvas.drawPath(frame, stroke);
  }

  void _stop(Canvas canvas, double s, Paint stroke) {
    final ring = _phase(0, 0.62);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(s / 2, s / 2), radius: s * 0.34),
      -math.pi / 2,
      math.pi * 2 * ring,
      false,
      stroke,
    );
    final bar = _phase(0.5, 1);
    if (bar > 0) {
      final left = Offset(s * 0.3, s * 0.5);
      final right = Offset(s * 0.7, s * 0.5);
      canvas.drawLine(left, Offset.lerp(left, right, bar)!, stroke);
    }
  }

  void _bell(Canvas canvas, double s, Paint stroke, Paint fill) {
    // Swing decays instead of stopping dead: a bell that halts mid-air reads
    // as a dropped frame.
    final swing = math.sin(t * math.pi * 3) * (1 - t) * 0.35;
    canvas.save();
    canvas.translate(s / 2, s * 0.2);
    canvas.rotate(swing);
    canvas.translate(-s / 2, -s * 0.2);
    final body = Path()
      ..moveTo(s * 0.24, s * 0.66)
      ..lineTo(s * 0.24, s * 0.46)
      ..arcToPoint(
        Offset(s * 0.76, s * 0.46),
        radius: Radius.circular(s * 0.3),
        clockwise: true,
      )
      ..lineTo(s * 0.76, s * 0.66)
      ..close();
    canvas.drawPath(body, stroke);
    canvas.drawLine(
      Offset(s * 0.16, s * 0.66),
      Offset(s * 0.84, s * 0.66),
      stroke,
    );
    canvas.drawCircle(Offset(s / 2, s * 0.78), s * 0.06, fill);
    canvas.restore();
  }

  void _chart(Canvas canvas, double s, Paint stroke) {
    const heights = [0.30, 0.50, 0.40];
    // Columns, not strokes: a bar chart drawn with round caps reads as a comb.
    final bar = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.14
      ..strokeCap = StrokeCap.butt;
    for (var i = 0; i < heights.length; i++) {
      // Each column starts after the one before it, so the chart builds up.
      final grow = _phase(i * 0.18, 0.62 + i * 0.18);
      if (grow <= 0) continue;
      final x = s * (0.26 + i * 0.24);
      final base = s * 0.76;
      canvas.drawLine(
        Offset(x, base),
        Offset(x, base - s * heights[i] * grow),
        bar,
      );
    }
    canvas.drawLine(
      Offset(s * 0.18, s * 0.82),
      Offset(s * 0.82, s * 0.82),
      stroke,
    );
  }

  void _card(Canvas canvas, double s, Paint stroke) {
    final slide = (1 - _phase(0, 0.55)) * s * 0.3;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.12 + slide, s * 0.28, s * 0.76, s * 0.44),
      Radius.circular(s * 0.08),
    );
    canvas.drawRRect(rect, stroke);
    final stripe = _phase(0.45, 1);
    if (stripe > 0) {
      final y = s * 0.44;
      canvas.drawLine(
        Offset(s * 0.12 + slide, y),
        Offset(s * 0.12 + slide + s * 0.76 * stripe, y),
        stroke,
      );
    }
  }

  void _tag(Canvas canvas, double s, Paint stroke, Paint fill) {
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.rotate((1 - t) * -0.6);
    canvas.translate(-s / 2, -s / 2);
    // Square corner at the top left, point at the bottom right. Symmetry here
    // produces a diamond, which is a different object entirely.
    final body = Path()
      ..moveTo(s * 0.14, s * 0.14)
      ..lineTo(s * 0.52, s * 0.14)
      ..lineTo(s * 0.88, s * 0.50)
      ..lineTo(s * 0.50, s * 0.88)
      ..lineTo(s * 0.14, s * 0.52)
      ..close();
    canvas.drawPath(body, stroke);
    final hole = _phase(0.6, 1);
    if (hole > 0) {
      canvas.drawCircle(Offset(s * 0.30, s * 0.30), s * 0.06 * hole, fill);
    }
    canvas.restore();
  }

  void _pot(Canvas canvas, double s, Paint stroke) {
    final lift = _phase(0.3, 1) * s * 0.09;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(s * 0.24, s * 0.50, s * 0.52, s * 0.30),
        bottomLeft: Radius.circular(s * 0.11),
        bottomRight: Radius.circular(s * 0.11),
      ),
      stroke,
    );
    // Side handles: without them the body is just a tub.
    canvas.drawLine(
      Offset(s * 0.16, s * 0.58),
      Offset(s * 0.24, s * 0.58),
      stroke,
    );
    canvas.drawLine(
      Offset(s * 0.76, s * 0.58),
      Offset(s * 0.84, s * 0.58),
      stroke,
    );
    canvas.drawLine(
      Offset(s * 0.18, s * 0.46 - lift),
      Offset(s * 0.82, s * 0.46 - lift),
      stroke,
    );
    // Steam curls rather than standing up straight — two vertical sticks above
    // a pot read as antennae.
    final steam = _phase(0.5, 1);
    if (steam > 0) {
      for (var i = 0; i < 2; i++) {
        final x = s * (0.40 + i * 0.20);
        final top = s * 0.40 - lift;
        final curl = Path()
          ..moveTo(x, top)
          ..cubicTo(
            x - s * 0.07,
            top - s * 0.08 * steam,
            x + s * 0.07,
            top - s * 0.14 * steam,
            x,
            top - s * 0.24 * steam,
          );
        canvas.drawPath(curl, stroke);
      }
    }
  }

  void _grid(Canvas canvas, double s, Paint stroke) {
    const cells = [
      [0, 0],
      [1, 0],
      [0, 1],
      [1, 1],
    ];
    for (var i = 0; i < cells.length; i++) {
      final appear = _phase(i * 0.14, 0.5 + i * 0.14);
      if (appear <= 0) continue;
      final side = s * 0.28 * appear;
      final cx = s * (0.34 + cells[i][0] * 0.32);
      final cy = s * (0.34 + cells[i][1] * 0.32);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: side, height: side),
          Radius.circular(s * 0.05),
        ),
        stroke,
      );
    }
  }

  void _plus(Canvas canvas, double s, Paint stroke) {
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.rotate((1 - t) * math.pi / 2);
    final arm = s * 0.3 * (0.4 + 0.6 * t);
    canvas.drawLine(Offset(-arm, 0), Offset(arm, 0), stroke);
    canvas.drawLine(Offset(0, -arm), Offset(0, arm), stroke);
    canvas.restore();
  }

  void _wallet(Canvas canvas, double s, Paint stroke, Paint fill) {
    final top = s * 0.40;
    // The coin falls in and is swallowed by the wallet: clipping above the top
    // edge is what sells "into", instead of a disc parked on the lid.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, s, top));
    final drop = _phase(0, 0.75);
    canvas.drawCircle(
      Offset(s * 0.62, s * 0.10 + s * 0.34 * drop),
      s * 0.09,
      fill,
    );
    canvas.restore();

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.12, top, s * 0.76, s * 0.42),
        Radius.circular(s * 0.09),
      ),
      stroke,
    );
    // Clasp on the right edge — the detail that separates a wallet from a card.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.62, s * 0.55, s * 0.22, s * 0.14),
        Radius.circular(s * 0.07),
      ),
      stroke,
    );
    canvas.drawCircle(Offset(s * 0.73, s * 0.62), s * 0.03, fill);
  }

  void _search(Canvas canvas, double s, Paint stroke) {
    canvas.drawCircle(Offset(s * 0.44, s * 0.44), s * 0.24, stroke);
    final handle = _phase(0.4, 1);
    if (handle > 0) {
      final from = Offset(s * 0.62, s * 0.62);
      final to = Offset(s * 0.84, s * 0.84);
      canvas.drawLine(from, Offset.lerp(from, to, handle)!, stroke);
    }
  }

  @override
  bool shouldRepaint(_ShapePainter old) =>
      old.t != t || old.raw != raw || old.color != color || old.shape != shape;
}
