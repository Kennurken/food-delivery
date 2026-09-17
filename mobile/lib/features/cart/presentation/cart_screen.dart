import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/money.dart';
import '../../orders/data/order_repository.dart';
import '../../restaurants/data/restaurant_repository.dart';
import 'cart_controller.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _address = TextEditingController();
  final _comment = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _address.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    if (_address.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter delivery address')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final order = await ref.read(orderRepositoryProvider).create(
            cart: cart,
            address: _address.text.trim(),
            comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
          );
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(ordersProvider);
      if (mounted) {
        // Reset stack to home -> orders -> detail so back navigation makes sense.
        context.go('/orders');
        context.push('/orders/${order.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final restaurant =
        cart.restaurantId == null ? null : ref.watch(restaurantProvider(cart.restaurantId!)).value;
    final fee = restaurant?.deliveryFee ?? 0;

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: const Center(child: Text('Cart is empty')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(restaurant?.name ?? 'Cart')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final line in cart.items.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(line.item.name),
              subtitle: Text(formatMoney(line.item.price)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => ref.read(cartProvider.notifier).remove(line.item),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('${line.quantity}'),
                  IconButton(
                    onPressed: () => ref.read(cartProvider.notifier).add(line.item),
                    icon: const Icon(Icons.add_circle),
                  ),
                ],
              ),
            ),
          const Divider(),
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Delivery address', prefixIcon: Icon(Icons.place)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            decoration: const InputDecoration(labelText: 'Comment for courier (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          _Row('Subtotal', formatMoney(cart.subtotal)),
          _Row('Delivery', formatMoney(fee)),
          const SizedBox(height: 4),
          _Row('Total', formatMoney(cart.subtotal + fee), bold: true),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _submitting ? null : _checkout,
            child: _submitting
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Place order · ${formatMoney(cart.subtotal + fee)}'),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? Theme.of(context).textTheme.titleMedium : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
