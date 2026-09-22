import '../../cart/domain/cart_item.dart';
import '../../restaurants/domain/menu_item.dart';
import 'order.dart';

class ReorderPlan {
  const ReorderPlan({this.items = const [], this.skipped = 0});

  final List<CartItem> items;
  final int skipped;

  bool get isEmpty => items.isEmpty;
}

/// Live menu + last order → cart lines. Current price/availability win;
/// deleted or 86'd dishes are skipped. Keep modifiers if they still exist,
/// otherwise fall back to today's defaults.
ReorderPlan planReorder({
  required List<OrderItem> ordered,
  required List<MenuItem> menu,
}) {
  final byId = {for (final m in menu) m.id: m};
  final items = <CartItem>[];
  var skipped = 0;
  for (final line in ordered) {
    final m = byId[line.menuItemId];
    if (m == null || !m.isAvailable) {
      skipped++;
      continue;
    }
    final wanted = line.optionIds;
    final ids = m.accepts(wanted)
        ? wanted
        : (m.accepts(m.defaultOptionIds) ? m.defaultOptionIds : null);
    if (ids == null) {
      skipped++;
      continue;
    }
    items.add(CartItem(item: m, quantity: line.quantity, optionIds: ids));
  }
  return ReorderPlan(items: items, skipped: skipped);
}
