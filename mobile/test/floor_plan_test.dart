import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/admin/floor_plan/domain/geometry.dart';
import 'package:food_delivery/features/admin/floor_plan/domain/history.dart';
import 'package:food_delivery/features/admin/floor_plan/domain/models.dart';

LayoutNode node(
  int id, {
  double x = 0,
  double y = 0,
  double w = 100,
  double h = 80,
}) => LayoutNode(
  id: id,
  kind: LayoutKind.tableRound,
  x: x,
  y: y,
  width: w,
  height: h,
);

void main() {
  test('snap rounds to grid', () {
    expect(snapValue(47, 40), 40);
    expect(snapValue(61, 40), 80);
  });

  test('align left', () {
    final a = node(1, x: 40);
    final b = node(2, x: 120);
    alignLeft([a, b]);
    expect(a.x, 40);
    expect(b.x, 40);
  });

  test('history undo redo', () {
    final h = DocHistory();
    final a = FloorDoc(
      id: 1,
      restaurantId: 1,
      name: 'A',
      sortOrder: 0,
      widthCm: 2000,
      heightCm: 1400,
      gridCm: 40,
      updatedAt: 't',
      zones: [],
      objects: [node(1, x: 10)],
    );
    h.push(a);
    final b = a.copy()..objects.first.x = 50;
    final undone = h.undo(b)!;
    expect(undone.objects.first.x, 10);
    final redone = h.redo(undone)!;
    expect(redone.objects.first.x, 50);
  });

  test('overlap warning', () {
    final w = layoutWarnings(
      objects: [node(1, x: 0, y: 0), node(2, x: 20, y: 10)],
      floorW: 2000,
      floorH: 1400,
    );
    expect(w.any((e) => e.kind == LayoutWarningKind.overlap), isTrue);
  });

  test('outside warning', () {
    final w = layoutWarnings(
      objects: [node(1, x: 1990, y: 0, w: 40)],
      floorW: 2000,
      floorH: 1400,
    );
    expect(w.any((e) => e.kind == LayoutWarningKind.outside), isTrue);
  });

  test('snapMove aligns to grid', () {
    final r = snapMove(
      moving: const LayoutRect(38, 10, 100, 80),
      others: const [LayoutRect(200, 10, 100, 80)],
      grid: 40,
      snapGrid: true,
    );
    expect(r.x, 40);
  });
}
