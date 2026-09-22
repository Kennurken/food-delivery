import 'models.dart';

double snapValue(double v, double grid, {bool enabled = true}) {
  if (!enabled || grid <= 0) return v;
  return (v / grid).round() * grid;
}

/// Snap a rect's origin to the grid.
LayoutRect snapRect(LayoutRect r, double grid, {bool enabled = true}) =>
    LayoutRect(
      snapValue(r.x, grid, enabled: enabled),
      snapValue(r.y, grid, enabled: enabled),
      r.w,
      r.h,
    );

class AlignGuide {
  const AlignGuide({required this.vertical, required this.at});

  final bool vertical;
  final double at;
}

class SnapResult {
  const SnapResult(this.x, this.y, this.guides);
  final double x;
  final double y;
  final List<AlignGuide> guides;
}

/// Snap to grid, then to other objects' edges/centers (6 cm threshold).
SnapResult snapMove({
  required LayoutRect moving,
  required List<LayoutRect> others,
  required double grid,
  required bool snapGrid,
  bool snapObjects = true,
  double threshold = 6,
}) {
  var x = snapValue(moving.x, grid, enabled: snapGrid);
  var y = snapValue(moving.y, grid, enabled: snapGrid);
  final guides = <AlignGuide>[];
  if (!snapObjects) return SnapResult(x, y, guides);

  final mx = LayoutRect(x, y, moving.w, moving.h);
  double? bestDx;
  double? bestDy;
  AlignGuide? gx;
  AlignGuide? gy;

  void considerX(double from, double to) {
    final d = to - from;
    if (d.abs() <= threshold && (bestDx == null || d.abs() < bestDx!.abs())) {
      bestDx = d;
      gx = AlignGuide(vertical: true, at: to);
    }
  }

  void considerY(double from, double to) {
    final d = to - from;
    if (d.abs() <= threshold && (bestDy == null || d.abs() < bestDy!.abs())) {
      bestDy = d;
      gy = AlignGuide(vertical: false, at: to);
    }
  }

  for (final o in others) {
    considerX(mx.x, o.x);
    considerX(mx.right, o.right);
    considerX(mx.cx, o.cx);
    considerY(mx.y, o.y);
    considerY(mx.bottom, o.bottom);
    considerY(mx.cy, o.cy);
  }
  if (bestDx != null) {
    x += bestDx!;
    guides.add(gx!);
  }
  if (bestDy != null) {
    y += bestDy!;
    guides.add(gy!);
  }
  return SnapResult(x, y, guides);
}

void alignLeft(List<LayoutNode> nodes) {
  if (nodes.isEmpty) return;
  final x = nodes.map((n) => n.x).reduce((a, b) => a < b ? a : b);
  for (final n in nodes) {
    n.x = x;
  }
}

void alignRight(List<LayoutNode> nodes) {
  if (nodes.isEmpty) return;
  final r = nodes.map((n) => n.rect.right).reduce((a, b) => a > b ? a : b);
  for (final n in nodes) {
    n.x = r - n.width;
  }
}

void alignCenter(List<LayoutNode> nodes) {
  if (nodes.isEmpty) return;
  final c = nodes.map((n) => n.rect.cx).reduce((a, b) => a + b) / nodes.length;
  for (final n in nodes) {
    n.x = c - n.width / 2;
  }
}

void alignTop(List<LayoutNode> nodes) {
  if (nodes.isEmpty) return;
  final y = nodes.map((n) => n.y).reduce((a, b) => a < b ? a : b);
  for (final n in nodes) {
    n.y = y;
  }
}

void alignBottom(List<LayoutNode> nodes) {
  if (nodes.isEmpty) return;
  final b = nodes.map((n) => n.rect.bottom).reduce((a, b) => a > b ? a : b);
  for (final n in nodes) {
    n.y = b - n.height;
  }
}

void alignMiddle(List<LayoutNode> nodes) {
  if (nodes.isEmpty) return;
  final c = nodes.map((n) => n.rect.cy).reduce((a, b) => a + b) / nodes.length;
  for (final n in nodes) {
    n.y = c - n.height / 2;
  }
}

void distributeH(List<LayoutNode> nodes) {
  if (nodes.length < 3) return;
  final sorted = [...nodes]..sort((a, b) => a.x.compareTo(b.x));
  final span = sorted.last.rect.right - sorted.first.x;
  final used = sorted.fold<double>(0, (s, n) => s + n.width);
  final gap = (span - used) / (sorted.length - 1);
  var cursor = sorted.first.x;
  for (final n in sorted) {
    n.x = cursor;
    cursor += n.width + gap;
  }
}

void distributeV(List<LayoutNode> nodes) {
  if (nodes.length < 3) return;
  final sorted = [...nodes]..sort((a, b) => a.y.compareTo(b.y));
  final span = sorted.last.rect.bottom - sorted.first.y;
  final used = sorted.fold<double>(0, (s, n) => s + n.height);
  final gap = (span - used) / (sorted.length - 1);
  var cursor = sorted.first.y;
  for (final n in sorted) {
    n.y = cursor;
    cursor += n.height + gap;
  }
}

enum LayoutWarningKind { overlap, outside, doorBlocked, clearance }

class LayoutWarning {
  const LayoutWarning(this.kind, this.objectId, this.message);
  final LayoutWarningKind kind;
  final int objectId;
  final String message;
}

List<LayoutWarning> layoutWarnings({
  required List<LayoutNode> objects,
  required double floorW,
  required double floorH,
}) {
  final out = <LayoutWarning>[];
  for (final a in objects) {
    if (a.x < 0 || a.y < 0 || a.rect.right > floorW || a.rect.bottom > floorH) {
      out.add(LayoutWarning(LayoutWarningKind.outside, a.id, 'outside'));
    }
  }
  for (var i = 0; i < objects.length; i++) {
    for (var j = i + 1; j < objects.length; j++) {
      final a = objects[i];
      final b = objects[j];
      if (a.kind.isWallLike && b.kind.isWallLike) continue;
      if (a.rect.overlaps(b.rect, inset: 2)) {
        out.add(LayoutWarning(LayoutWarningKind.overlap, a.id, 'overlap'));
      }
      if (a.kind.isTable && b.kind.isTable) {
        final gap = _gap(a.rect, b.rect);
        if (gap >= 0 && gap < 60) {
          out.add(
            LayoutWarning(LayoutWarningKind.clearance, a.id, 'clearance'),
          );
        }
      }
    }
  }
  for (final door in objects.where((o) => o.kind.wire == 'door')) {
    final swing = LayoutRect(door.x, door.y - 80, door.width, 80);
    for (final o in objects) {
      if (o.id == door.id) continue;
      if (swing.overlaps(o.rect, inset: 4)) {
        out.add(LayoutWarning(LayoutWarningKind.doorBlocked, door.id, 'door'));
        break;
      }
    }
  }
  return out;
}

double _gap(LayoutRect a, LayoutRect b) {
  final dx = a.cx < b.cx ? b.x - a.right : a.x - b.right;
  final dy = a.cy < b.cy ? b.y - a.bottom : a.y - b.bottom;
  if (dx < 0 && dy < 0) return 0;
  if (dx < 0) return dy;
  if (dy < 0) return dx;
  return dx < dy ? dx : dy;
}
