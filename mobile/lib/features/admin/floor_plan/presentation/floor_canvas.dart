import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/geometry.dart';
import '../domain/models.dart';
import 'editor_controller.dart';
import 'object_painter.dart';
import 'plan_theme.dart';

enum _Grip { body, nw, n, ne, e, se, s, sw, w, rot, zone, none }

class FloorCanvas extends StatefulWidget {
  const FloorCanvas({super.key, required this.editor});

  final FloorEditor editor;

  @override
  State<FloorCanvas> createState() => _FloorCanvasState();
}

class _FloorCanvasState extends State<FloorCanvas> {
  Offset _origin = const Offset(48, 48);
  double _scale = 0.5;
  Offset? _pan0;
  Offset? _origin0;
  int? _dragId;
  Offset? _dragWorld0;
  Offset? _node0;
  Size? _nodeSize0;
  double _rot0 = 0;
  _Grip _grip = _Grip.none;
  Offset? _marquee0;
  Offset? _marquee1;
  bool _editStarted = false;
  int? _fittedId;

  FloorEditor get e => widget.editor;

  Offset _toWorld(Offset s) => (s - _origin) / _scale;
  Offset _toScreen(Offset w) => _origin + w * _scale;

  bool get _space => HardwareKeyboard.instance.logicalKeysPressed.contains(
    LogicalKeyboardKey.space,
  );

  bool get _shift =>
      HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftLeft,
      ) ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftRight,
      );

  void _fit() {
    final d = e.doc;
    if (d == null || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size ?? context.size;
    if (size == null || size.isEmpty) return;
    final sx = (size.width - 96) / d.widthCm;
    final sy = (size.height - 96) / d.heightCm;
    setState(() {
      _scale = (sx < sy ? sx : sy).clamp(0.12, 2.5);
      _origin = Offset(
        (size.width - d.widthCm * _scale) / 2,
        (size.height - d.heightCm * _scale) / 2,
      );
    });
  }

  void _reset() => setState(() {
    _origin = const Offset(48, 48);
    _scale = 0.5;
  });

  void _zoomAt(Offset screen, double factor) {
    final world = _toWorld(screen);
    final next = (_scale * factor).clamp(0.12, 3.0);
    setState(() {
      _scale = next;
      _origin = screen - world * _scale;
    });
  }

  void _zoomCenter(double factor) {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size;
    if (size == null) {
      setState(() => _scale = (_scale * factor).clamp(0.12, 3.0));
      return;
    }
    _zoomAt(Offset(size.width / 2, size.height / 2), factor);
  }

  Rect _screenRect(LayoutRect r) => Rect.fromLTWH(
    _origin.dx + r.x * _scale,
    _origin.dy + r.y * _scale,
    r.w * _scale,
    r.h * _scale,
  );

  Map<_Grip, Offset> _handles(LayoutRect r) {
    final s = _screenRect(r);
    return {
      _Grip.nw: s.topLeft,
      _Grip.n: s.topCenter,
      _Grip.ne: s.topRight,
      _Grip.e: s.centerRight,
      _Grip.se: s.bottomRight,
      _Grip.s: s.bottomCenter,
      _Grip.sw: s.bottomLeft,
      _Grip.w: s.centerLeft,
      _Grip.rot: s.topCenter.translate(0, -22),
    };
  }

  _Grip _hitHandle(Offset screen, LayoutRect r) {
    final hs = _handles(r);
    for (final e in hs.entries) {
      if ((e.value - screen).distance <= 8) return e.key;
    }
    return _Grip.none;
  }

  LayoutNode? _hitObject(Offset world) {
    final d = e.doc;
    if (d == null) return null;
    for (final o in d.objects.reversed) {
      if (o.rect.containsPoint(world.dx, world.dy)) return o;
    }
    return null;
  }

  LayoutZone? _hitZone(Offset world) {
    final d = e.doc;
    if (d == null) return null;
    for (final z in d.zones.reversed) {
      if (z.rect.containsPoint(world.dx, world.dy)) return z;
    }
    return null;
  }

  void _ensureEdit() {
    if (_editStarted) return;
    _editStarted = true;
    e.beginEdit();
  }

  void _onDown(PointerDownEvent ev) {
    final d = e.doc;
    if (d == null) return;
    final world = _toWorld(ev.localPosition);
    _editStarted = false;

    if (e.placing != null) {
      e.placeAt(world.dx, world.dy);
      return;
    }
    if (e.preview ||
        _space ||
        ev.buttons == kMiddleMouseButton ||
        ev.buttons == kSecondaryMouseButton) {
      _pan0 = ev.localPosition;
      _origin0 = _origin;
      return;
    }

    if (e.selected.length == 1) {
      final n = e.primary;
      if (n != null) {
        final g = _hitHandle(ev.localPosition, n.rect);
        if (g != _Grip.none) {
          _grip = g;
          _dragId = n.id;
          _dragWorld0 = world;
          _node0 = Offset(n.x, n.y);
          _nodeSize0 = Size(n.width, n.height);
          _rot0 = n.rotation;
          return;
        }
      }
    }

    final hit = _hitObject(world);
    if (hit != null) {
      if (_shift) {
        e.select(hit.id, additive: true);
      } else if (!e.selected.contains(hit.id)) {
        e.select(hit.id);
      }
      _grip = _Grip.body;
      _dragId = hit.id;
      _dragWorld0 = world;
      _node0 = Offset(hit.x, hit.y);
      return;
    }

    final zone = _hitZone(world);
    if (zone != null) {
      e.selectZone(zone.id);
      _grip = _Grip.zone;
      _dragId = zone.id;
      _dragWorld0 = world;
      _node0 = Offset(zone.x, zone.y);
      return;
    }

    if (!_shift) e.deselect();
    _marquee0 = world;
    _marquee1 = world;
    setState(() {});
  }

  void _onMove(PointerMoveEvent ev) {
    if (_pan0 != null && _origin0 != null) {
      setState(() => _origin = _origin0! + (ev.localPosition - _pan0!));
      return;
    }
    final world = _toWorld(ev.localPosition);
    if (_dragId != null && _dragWorld0 != null && _node0 != null) {
      _ensureEdit();
      final delta = world - _dragWorld0!;
      if (_grip == _Grip.body) {
        e.moveSelectedTo(
          _dragId!,
          _node0!.dx + delta.dx,
          _node0!.dy + delta.dy,
        );
      } else if (_grip == _Grip.zone) {
        e.moveZoneTo(_dragId!, _node0!.dx + delta.dx, _node0!.dy + delta.dy);
      } else if (_grip == _Grip.rot) {
        final n = e.primary;
        if (n != null) {
          final c = Offset(n.x + n.width / 2, n.y + n.height / 2);
          final a0 = math.atan2(_dragWorld0!.dy - c.dy, _dragWorld0!.dx - c.dx);
          final a1 = math.atan2(world.dy - c.dy, world.dx - c.dx);
          e.rotate(_dragId!, _rot0 + (a1 - a0) * 180 / math.pi);
        }
      } else if (_nodeSize0 != null) {
        _resize(world);
      }
      return;
    }
    if (_marquee0 != null) {
      setState(() => _marquee1 = world);
    }
  }

  void _resize(Offset world) {
    final origin = _node0!;
    final size = _nodeSize0!;
    var x = origin.dx;
    var y = origin.dy;
    var w = size.width;
    var h = size.height;
    final right = origin.dx + size.width;
    final bottom = origin.dy + size.height;
    switch (_grip) {
      case _Grip.se:
        w = world.dx - x;
        h = world.dy - y;
      case _Grip.e:
        w = world.dx - x;
      case _Grip.s:
        h = world.dy - y;
      case _Grip.nw:
        x = world.dx;
        y = world.dy;
        w = right - x;
        h = bottom - y;
      case _Grip.n:
        y = world.dy;
        h = bottom - y;
      case _Grip.w:
        x = world.dx;
        w = right - x;
      case _Grip.ne:
        y = world.dy;
        w = world.dx - x;
        h = bottom - y;
      case _Grip.sw:
        x = world.dx;
        w = right - x;
        h = world.dy - y;
      default:
        return;
    }
    if (w < 16) {
      w = 16;
      if (_grip == _Grip.nw || _grip == _Grip.w || _grip == _Grip.sw) {
        x = right - 16;
      }
    }
    if (h < 16) {
      h = 16;
      if (_grip == _Grip.nw || _grip == _Grip.n || _grip == _Grip.ne) {
        y = bottom - 16;
      }
    }
    e.applyRect(_dragId!, x, y, w, h);
  }

  void _onUp(PointerEvent ev) {
    if (_marquee0 != null && _marquee1 != null) {
      final a = _marquee0!;
      final b = _marquee1!;
      final r = LayoutRect(
        a.dx < b.dx ? a.dx : b.dx,
        a.dy < b.dy ? a.dy : b.dy,
        (a.dx - b.dx).abs(),
        (a.dy - b.dy).abs(),
      );
      if (r.w > 8 && r.h > 8 && e.doc != null) {
        e.selectOnly({
          for (final o in e.doc!.objects)
            if (r.overlaps(o.rect)) o.id,
        });
      }
    }
    _pan0 = null;
    _dragId = null;
    _marquee0 = null;
    _marquee1 = null;
    _grip = _Grip.none;
    _editStarted = false;
    e.endGesture();
    setState(() {});
  }

  @override
  void didUpdateWidget(FloorCanvas old) {
    super.didUpdateWidget(old);
    final id = e.doc?.id;
    if (id != null && id != _fittedId) {
      _fittedId = id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fittedId = e.doc?.id;
      _fit();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([e, e.canvasGen]),
      builder: (context, _) {
        final d = e.doc;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onDown,
          onPointerMove: _onMove,
          onPointerUp: _onUp,
          onPointerCancel: _onUp,
          onPointerSignal: (s) {
            if (s is PointerScrollEvent) {
              _zoomAt(s.localPosition, s.scrollDelta.dy > 0 ? 0.92 : 1.08);
            }
          },
          child: MouseRegion(
            cursor: e.placing != null
                ? SystemMouseCursors.precise
                : (_space ? SystemMouseCursors.grab : SystemMouseCursors.basic),
            child: ClipRect(
              // LayoutBuilder gives the viewport size during build; context.size
              // is not available yet at this point and asserts.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewSize = constraints.biggest;
                  return Stack(
                    children: [
                      ColoredBox(color: PlanTheme.canvas(context)),
                      if (d != null)
                        CustomPaint(
                          painter: _PlanPainter(
                            doc: d,
                            origin: _origin,
                            scale: _scale,
                            selected: e.selected,
                            selectedZone: e.selectedZone,
                            preview: e.preview,
                            dark:
                                Theme.of(context).brightness == Brightness.dark,
                            warnIds: {for (final w in e.warnings) w.objectId},
                            guides: e.guides,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      if (_marquee0 != null && _marquee1 != null) _marquee(),
                      if (!e.preview) _hud(),
                      if (!e.preview) _minimap(d, viewSize),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _marquee() {
    final a = _toScreen(_marquee0!);
    final b = _toScreen(_marquee1!);
    return Positioned.fromRect(
      rect: Rect.fromPoints(a, b),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PlanTheme.select.withValues(alpha: 0.1),
          border: Border.all(color: PlanTheme.select, width: 1),
        ),
      ),
    );
  }

  Widget _hud() {
    return Positioned(
      left: 12,
      bottom: 12,
      child: Material(
        color: PlanTheme.panel(context).withValues(alpha: 0.96),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: PlanTheme.hairline(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Zoom out',
              visualDensity: VisualDensity.compact,
              onPressed: () => _zoomCenter(0.85),
              icon: const Icon(Icons.remove, size: 18),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${(_scale * 100).round()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Zoom in',
              visualDensity: VisualDensity.compact,
              onPressed: () => _zoomCenter(1.15),
              icon: const Icon(Icons.add, size: 18),
            ),
            IconButton(
              tooltip: 'Fit to screen',
              visualDensity: VisualDensity.compact,
              onPressed: _fit,
              icon: const Icon(Icons.fit_screen, size: 18),
            ),
            IconButton(
              tooltip: 'Reset view',
              visualDensity: VisualDensity.compact,
              onPressed: _reset,
              icon: const Icon(Icons.crop_free, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _minimap(FloorDoc? d, Size viewSize) {
    if (d == null || viewSize.isEmpty) return const SizedBox.shrink();
    return Positioned(
      right: 12,
      bottom: 12,
      child: _MiniMap(
        doc: d,
        origin: _origin,
        scale: _scale,
        viewSize: viewSize,
        onTapWorld: (w) => setState(
          () => _origin =
              Offset(viewSize.width / 2, viewSize.height / 2) - w * _scale,
        ),
      ),
    );
  }
}

class _PlanPainter extends CustomPainter {
  _PlanPainter({
    required this.doc,
    required this.origin,
    required this.scale,
    required this.selected,
    required this.selectedZone,
    required this.preview,
    required this.dark,
    required this.warnIds,
    required this.guides,
  });

  final FloorDoc doc;
  final Offset origin;
  final double scale;
  final Set<int> selected;
  final int? selectedZone;
  final bool preview;
  final bool dark;
  final Set<int> warnIds;
  final List<AlignGuide> guides;

  @override
  void paint(Canvas canvas, Size size) {
    final floor = Rect.fromLTWH(
      origin.dx,
      origin.dy,
      doc.widthCm * scale,
      doc.heightCm * scale,
    );
    canvas.drawRect(
      floor,
      Paint()..color = dark ? PlanTheme.floorDark : PlanTheme.floor,
    );
    if (!preview) _grid(canvas, floor);
    canvas.drawRect(
      floor,
      Paint()
        ..color = dark
            ? const Color(0x55FFFFFF)
            : PlanTheme.ink.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    for (final z in doc.zones) {
      final r = Rect.fromLTWH(
        origin.dx + z.x * scale,
        origin.dy + z.y * scale,
        z.width * scale,
        z.height * scale,
      );
      final color = _parse(z.color);
      final active = selectedZone == z.id;
      canvas.drawRect(
        r,
        Paint()..color = color.withValues(alpha: active ? 0.34 : 0.18),
      );
      canvas.drawRect(
        r,
        Paint()
          ..color = color.withValues(alpha: active ? 0.95 : 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = active ? 1.6 : 1,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: z.name.toUpperCase(),
          style: TextStyle(
            color: PlanTheme.ink.withValues(alpha: 0.45),
            fontSize: (11 * scale).clamp(9, 13),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r.width - 8);
      tp.paint(canvas, r.topLeft + const Offset(8, 6));
    }

    for (final o in doc.objects) {
      canvas.save();
      final cx = origin.dx + (o.x + o.width / 2) * scale;
      final cy = origin.dy + (o.y + o.height / 2) * scale;
      canvas.translate(cx, cy);
      canvas.rotate(o.rotation * math.pi / 180);
      canvas.translate(-o.width * scale / 2, -o.height * scale / 2);
      ObjectPainter(
        node: o,
        selected: selected.contains(o.id),
        preview: preview,
        warn: warnIds.contains(o.id),
      ).paint(canvas, Size(o.width * scale, o.height * scale));
      canvas.restore();
    }

    if (!preview && selected.length == 1) {
      LayoutNode? n;
      for (final o in doc.objects) {
        if (o.id == selected.first) n = o;
      }
      if (n != null) _handles(canvas, n.rect);
    }

    if (!preview) {
      final p = Paint()
        ..color = PlanTheme.select
        ..strokeWidth = 1;
      for (final g in guides) {
        if (g.vertical) {
          final x = origin.dx + g.at * scale;
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        } else {
          final y = origin.dy + g.at * scale;
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
      }
    }
  }

  void _grid(Canvas canvas, Rect floor) {
    final grid = doc.gridCm.toDouble();
    if (grid * scale < 6) return;
    final minor = Paint()
      ..color = dark ? const Color(0x18FFFFFF) : const Color(0x1A241F1B)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = dark ? const Color(0x28FFFFFF) : const Color(0x2A241F1B)
      ..strokeWidth = 1;
    for (double x = 0; x <= doc.widthCm; x += grid) {
      final sx = origin.dx + x * scale;
      final majorLine = x % (grid * 5) == 0;
      canvas.drawLine(
        Offset(sx, floor.top),
        Offset(sx, floor.bottom),
        majorLine ? major : minor,
      );
    }
    for (double y = 0; y <= doc.heightCm; y += grid) {
      final sy = origin.dy + y * scale;
      final majorLine = y % (grid * 5) == 0;
      canvas.drawLine(
        Offset(floor.left, sy),
        Offset(floor.right, sy),
        majorLine ? major : minor,
      );
    }
  }

  void _handles(Canvas canvas, LayoutRect r) {
    final s = Rect.fromLTWH(
      origin.dx + r.x * scale,
      origin.dy + r.y * scale,
      r.w * scale,
      r.h * scale,
    );
    final pts = [
      s.topLeft,
      s.topCenter,
      s.topRight,
      s.centerRight,
      s.bottomRight,
      s.bottomCenter,
      s.bottomLeft,
      s.centerLeft,
    ];
    final fill = Paint()..color = PlanTheme.handle;
    final stroke = Paint()
      ..color = PlanTheme.select
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final p in pts) {
      canvas.drawRect(Rect.fromCenter(center: p, width: 7, height: 7), fill);
      canvas.drawRect(Rect.fromCenter(center: p, width: 7, height: 7), stroke);
    }
    final rot = s.topCenter.translate(0, -22);
    canvas.drawLine(s.topCenter, rot, stroke);
    canvas.drawCircle(rot, 5, fill);
    canvas.drawCircle(rot, 5, stroke);
  }

  Color _parse(String hex) {
    final h = hex.replaceAll('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return const Color(0xFFD9CDB8);
  }

  @override
  bool shouldRepaint(_PlanPainter old) => true;
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({
    required this.doc,
    required this.origin,
    required this.scale,
    required this.viewSize,
    required this.onTapWorld,
  });

  final FloorDoc doc;
  final Offset origin;
  final double scale;
  final Size viewSize;
  final ValueChanged<Offset> onTapWorld;

  @override
  Widget build(BuildContext context) {
    const w = 148.0;
    const h = 100.0;
    final sx = w / doc.widthCm;
    final sy = h / doc.heightCm;
    final s = sx < sy ? sx : sy;
    return Material(
      color: PlanTheme.panel(context).withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: PlanTheme.hairline(context)),
      ),
      child: SizedBox(
        width: w,
        height: h,
        child: GestureDetector(
          onTapDown: (d) => onTapWorld(
            Offset(d.localPosition.dx / s, d.localPosition.dy / s),
          ),
          child: CustomPaint(
            painter: _MiniPainter(
              doc: doc,
              s: s,
              view: Rect.fromLTWH(
                -origin.dx / scale,
                -origin.dy / scale,
                viewSize.width / scale,
                viewSize.height / scale,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPainter extends CustomPainter {
  _MiniPainter({required this.doc, required this.s, required this.view});

  final FloorDoc doc;
  final double s;
  final Rect view;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x14000000),
    );
    for (final o in doc.objects) {
      canvas.drawRect(
        Rect.fromLTWH(o.x * s, o.y * s, o.width * s, o.height * s),
        Paint()
          ..color = o.kind.isTable
              ? PlanTheme.select
              : PlanTheme.ink.withValues(alpha: 0.4),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(
        view.left * s,
        view.top * s,
        view.width * s,
        view.height * s,
      ),
      Paint()
        ..color = PlanTheme.select
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_MiniPainter old) => true;
}
