import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'plan_theme.dart';

class ObjectPainter extends CustomPainter {
  ObjectPainter({
    required this.node,
    required this.selected,
    required this.preview,
    required this.warn,
    this.thumb = false,
  });

  final LayoutNode node;
  final bool selected;
  final bool preview;
  final bool warn;
  final bool thumb;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final r = Offset.zero & size;
    switch (node.kind) {
      case LayoutKind.tableRound:
        _table(canvas, r, round: true);
      case LayoutKind.tableSquare:
      case LayoutKind.tableRect:
      case LayoutKind.tableLarge:
      case LayoutKind.tableCustom:
        _table(canvas, r, round: false);
      case LayoutKind.chair:
      case LayoutKind.stool:
        _stool(canvas, r);
      case LayoutKind.sofa:
      case LayoutKind.booth:
        _sofa(canvas, r);
      case LayoutKind.reception:
      case LayoutKind.counter:
      case LayoutKind.bar:
        _bar(canvas, r);
      case LayoutKind.wall:
        _wall(canvas, r);
      case LayoutKind.door:
        _door(canvas, r);
      case LayoutKind.window:
        _window(canvas, r);
      case LayoutKind.column:
        _column(canvas, r);
      case LayoutKind.stairs:
        _stairs(canvas, r);
      case LayoutKind.elevator:
        _elev(canvas, r);
      case LayoutKind.kitchen:
        _block(canvas, r, const Color(0xFF9A8B78), 'KITCHEN');
      case LayoutKind.toilet:
        _block(canvas, r, const Color(0xFF6E7C7B), 'WC');
      case LayoutKind.entrance:
      case LayoutKind.exit:
        _portal(canvas, r);
    }
    if (selected && !preview && !thumb) {
      canvas.drawRRect(
        RRect.fromRectXY(r.inflate(3), 3, 3),
        Paint()
          ..color = PlanTheme.select
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
    if (warn && !preview && !thumb) {
      canvas.drawRect(
        r,
        Paint()..color = PlanTheme.warn.withValues(alpha: 0.16),
      );
    }
  }

  Color get _status {
    return switch (node.status) {
      TableStatus.available => const Color(0xFF2F6B3A),
      TableStatus.reserved => const Color(0xFFB8860B),
      TableStatus.occupied => const Color(0xFFB42318),
      TableStatus.cleaning => const Color(0xFF1D4E89),
      TableStatus.disabled => const Color(0xFF5C564E),
    };
  }

  void _table(Canvas canvas, Rect r, {required bool round}) {
    if (!thumb && r.shortestSide > 36) {
      _chairs(canvas, r, round: round);
    }
    final fill = Paint()..color = PlanTheme.tableFill;
    final stroke = Paint()
      ..color = PlanTheme.tableEdge.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thumb ? 1 : 1.3;
    if (round) {
      canvas.drawOval(r.deflate(thumb ? 1 : 10), fill);
      canvas.drawOval(r.deflate(thumb ? 1 : 10), stroke);
    } else {
      final rr = RRect.fromRectXY(r.deflate(thumb ? 1 : 10), 5, 5);
      canvas.drawRRect(rr, fill);
      canvas.drawRRect(rr, stroke);
    }
    if (thumb) return;
    final label = node.name.isEmpty ? '·' : node.name;
    _label(canvas, r.center, label, (r.shortestSide * 0.18).clamp(10, 15));
    canvas.drawCircle(
      Offset(r.left + 12, r.top + 12),
      4.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      Offset(r.left + 12, r.top + 12),
      3.5,
      Paint()..color = _status,
    );
    if (node.mergeGroup != null) {
      _label(
        canvas,
        Offset(r.center.dx, r.bottom - 12),
        '+',
        11,
        color: PlanTheme.select,
      );
    }
  }

  void _chairs(Canvas canvas, Rect r, {required bool round}) {
    final chair = Paint()..color = const Color(0xFF6A5648);
    final n = round ? 4 : 6;
    for (var i = 0; i < n; i++) {
      if (round) {
        final a = -math.pi / 2 + i * math.pi * 2 / n;
        final c = Offset(
          r.center.dx + math.cos(a) * (r.width / 2 - 7),
          r.center.dy + math.sin(a) * (r.height / 2 - 7),
        );
        canvas.drawCircle(c, 6, chair);
      } else {
        final alongTop = i < n / 2;
        final t = (i % (n ~/ 2) + 1) / (n / 2 + 1);
        final c = alongTop
            ? Offset(r.left + r.width * t, r.top + 6)
            : Offset(r.left + r.width * t, r.bottom - 6);
        canvas.drawRRect(
          RRect.fromRectXY(
            Rect.fromCenter(center: c, width: 12, height: 8),
            2,
            2,
          ),
          chair,
        );
      }
    }
  }

  void _stool(Canvas canvas, Rect r) {
    canvas.drawCircle(
      r.center,
      r.shortestSide / 2 - 1,
      Paint()..color = const Color(0xFF6B5344),
    );
    canvas.drawCircle(
      r.center,
      r.shortestSide / 4,
      Paint()..color = const Color(0xFF8A6D58),
    );
  }

  void _sofa(Canvas canvas, Rect r) {
    final rr = RRect.fromRectXY(r.deflate(1), 14, 14);
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF6E4F3A));
    canvas.drawRRect(
      RRect.fromRectXY(
        Rect.fromLTWH(r.left + 8, r.top + 8, r.width - 16, r.height * 0.42),
        8,
        8,
      ),
      Paint()..color = const Color(0xFF8A6A52),
    );
  }

  void _bar(Canvas canvas, Rect r) {
    canvas.drawRRect(RRect.fromRectXY(r, 3, 3), Paint()..color = PlanTheme.bar);
    if (!thumb) {
      _label(
        canvas,
        r.center,
        node.name.isEmpty
            ? node.kind.label.toUpperCase()
            : node.name.toUpperCase(),
        10,
        color: Colors.white,
      );
    }
  }

  void _wall(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = PlanTheme.wall);
  }

  void _door(Canvas canvas, Rect r) {
    final p = Paint()
      ..color = PlanTheme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(r.centerLeft, r.centerRight, p);
    if (thumb) return;
    final arc = Path()
      ..moveTo(r.left, r.center.dy)
      ..arcToPoint(
        Offset(r.left, r.center.dy - r.width * 0.65),
        radius: Radius.circular(r.width * 0.65),
        clockwise: false,
      );
    canvas.drawPath(arc, p..color = PlanTheme.ink.withValues(alpha: 0.4));
  }

  void _window(Canvas canvas, Rect r) {
    final p = Paint()
      ..color = const Color(0xFF5B7C8A)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(r.left, r.center.dy - 2.5),
      Offset(r.right, r.center.dy - 2.5),
      p,
    );
    canvas.drawLine(
      Offset(r.left, r.center.dy + 2.5),
      Offset(r.right, r.center.dy + 2.5),
      p,
    );
  }

  void _column(Canvas canvas, Rect r) {
    canvas.drawCircle(
      r.center,
      r.shortestSide / 2,
      Paint()..color = PlanTheme.wall,
    );
  }

  void _stairs(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = const Color(0x33241F1B));
    final p = Paint()
      ..color = PlanTheme.ink.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    const steps = 8;
    for (var i = 0; i <= steps; i++) {
      final y = r.top + r.height * i / steps;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), p);
    }
  }

  void _elev(Canvas canvas, Rect r) {
    canvas.drawRRect(
      RRect.fromRectXY(r.deflate(2), 3, 3),
      Paint()..color = const Color(0xFF4A4A48),
    );
    if (!thumb) _label(canvas, r.center, '↕', 16, color: Colors.white);
  }

  void _block(Canvas canvas, Rect r, Color color, String tag) {
    canvas.drawRRect(
      RRect.fromRectXY(r.deflate(1), 3, 3),
      Paint()..color = color,
    );
    if (!thumb) {
      _label(
        canvas,
        r.center,
        node.name.isEmpty ? tag : node.name,
        10,
        color: Colors.white,
      );
    }
  }

  void _portal(Canvas canvas, Rect r) {
    final p = Paint()
      ..color = PlanTheme.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(r.deflate(2), p);
    if (!thumb) {
      _label(
        canvas,
        r.center,
        node.kind == LayoutKind.exit ? 'EXIT' : 'IN',
        10,
      );
    }
  }

  void _label(
    Canvas canvas,
    Offset at,
    String text,
    double size, {
    Color color = PlanTheme.ink,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(ObjectPainter old) =>
      old.node.id != node.id ||
      old.node.x != node.x ||
      old.node.y != node.y ||
      old.node.width != node.width ||
      old.node.height != node.height ||
      old.node.rotation != node.rotation ||
      old.node.name != node.name ||
      old.node.status != node.status ||
      old.node.kind != node.kind ||
      old.node.mergeGroup != node.mergeGroup ||
      old.selected != selected ||
      old.preview != preview ||
      old.warn != warn;
}
