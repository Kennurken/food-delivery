import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/sliding_number.dart';
import '../../../core/widgets/stagger.dart';
import '../../../core/widgets/success_check.dart';
import '../../orders/data/order_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../restaurants/data/restaurant_repository.dart';
import '../../restaurants/presentation/restaurant_screen.dart'
    show QuantityStepper;
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
  int? _placedOrderId;

  @override
  void dispose() {
    _address.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    if (_address.text.trim().length < 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter delivery address')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .create(
            cart: cart,
            address: _address.text.trim(),
            comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
          );
      ref.read(cartProvider.notifier).clear();
      ref.invalidate(ordersProvider);
      if (!mounted) return;
      setState(() => _placedOrderId = order.id);
      // Let the success animation play before moving on.
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        context.go('/orders');
        context.push('/orders/${order.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final saved = ref.watch(addressesProvider).value ?? const [];
    ref.listen(addressesProvider, (_, next) {
      final def = next.value?.where((a) => a.isDefault).firstOrNull;
      if (def != null && _address.text.isEmpty) _address.text = def.line;
    });
    final restaurant = cart.restaurantId == null
        ? null
        : ref.watch(restaurantProvider(cart.restaurantId!)).value;
    final fee = restaurant?.deliveryFee ?? 0;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (_placedOrderId != null) return _SuccessView(orderId: _placedOrderId!);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: scheme.outline,
              ).animate().scale(curve: Motion.pop, duration: Motion.slow),
              const SizedBox(height: 12),
              const Text('Cart is empty'),
            ],
          ),
        ),
      );
    }

    var idx = 0;
    return Scaffold(
      appBar: AppBar(title: Text(restaurant?.name ?? 'Cart')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final line in cart.items.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.item.name,
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SlidingNumber(
                              formatMoney(line.lineTotal),
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      QuantityStepper(
                        qty: line.quantity,
                        onAdd: () =>
                            ref.read(cartProvider.notifier).add(line.item),
                        onRemove: () =>
                            ref.read(cartProvider.notifier).remove(line.item),
                      ),
                    ],
                  ),
                ),
              ),
            ).stagger(idx++),
          const SizedBox(height: 8),
          if (saved.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              children: [
                for (final a in saved)
                  ActionChip(
                    avatar: Icon(
                      a.isDefault ? Icons.home : Icons.place_outlined,
                      size: 18,
                    ),
                    label: Text(a.label),
                    onPressed: () => setState(() => _address.text = a.line),
                  ),
              ],
            ).stagger(idx++),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: 'Delivery address',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ).stagger(idx++),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            decoration: const InputDecoration(
              labelText: 'Comment for courier (optional)',
              prefixIcon: Icon(Icons.chat_bubble_outline),
            ),
            maxLines: 2,
          ).stagger(idx++),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _Row('Subtotal', formatMoney(cart.subtotal)),
                  _Row('Delivery', formatMoney(fee)),
                  const Divider(height: 20),
                  _Row('Total', formatMoney(cart.subtotal + fee), bold: true),
                ],
              ),
            ),
          ).stagger(idx++),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Pressable(
            onTap: _submitting ? null : _checkout,
            child: FilledButton(
              onPressed: _submitting ? null : _checkout,
              child: AnimatedSwitcher(
                duration: Motion.fast,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Place order'),
                          SlidingNumber(
                            formatMoney(cart.subtotal + fee),
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SuccessCheck(size: 120),
            const SizedBox(height: 24),
            Text(
                  'Order #$orderId placed',
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                )
                .animate(delay: 500.ms)
                .fadeIn(duration: Motion.normal)
                .slideY(begin: 0.3, end: 0, curve: Motion.enter),
            const SizedBox(height: 6),
            Text('We\'ll keep you posted', style: text.bodyMedium)
                .animate(delay: 650.ms)
                .fadeIn(duration: Motion.normal)
                .slideY(begin: 0.3, end: 0, curve: Motion.enter),
          ],
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
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          SlidingNumber(value, style: style),
        ],
      ),
    );
  }
}
