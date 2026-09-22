import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../restaurants/data/restaurant_repository.dart';
import '../domain/order.dart';
import '../domain/reorder.dart';

Future<void> reorderOrder(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  final t = context.l10n;
  final cart = ref.read(cartProvider);
  if (!cart.isEmpty && cart.restaurantId != order.restaurantId) {
    final replace = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.newCartTitle),
        content: Text(t.newCartBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.keep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.replace),
          ),
        ],
      ),
    );
    if (replace != true) return;
  }

  try {
    final restaurant = await ref
        .read(restaurantRepositoryProvider)
        .get(order.restaurantId);
    if (!context.mounted) return;
    if (!restaurant.isOpen) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.restaurantClosed)));
      return;
    }
    final plan = planReorder(ordered: order.items, menu: restaurant.menu);
    if (plan.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.nothingToReorder)));
      return;
    }
    ref
        .read(cartProvider.notifier)
        .replaceAll(
          plan.items,
          fulfillment: order.channel == 'pickup' ? 'pickup' : 'delivery',
        );
    if (plan.skipped > 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.someItemsUnavailable)));
    }
    if (context.mounted) context.push('/cart');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }
}
