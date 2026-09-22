import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';

import '../../../core/theme/motion.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/dish_thumb.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/sliding_number.dart';
import '../../../core/widgets/stagger.dart';
import '../../../core/widgets/success_check.dart';
import '../../map/domain/place.dart';
import '../../map/presentation/map_origin.dart';
import '../../orders/data/order_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/address.dart';
import '../../restaurants/data/restaurant_repository.dart';
import '../../restaurants/domain/restaurant.dart';
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
  void initState() {
    super.initState();
    final dest = ref.read(cartProvider).destLine;
    if (dest != null && dest.isNotEmpty) _address.text = dest;
  }

  @override
  void dispose() {
    _address.dispose();
    _comment.dispose();
    super.dispose();
  }

  bool _blocked(CartState cart, Restaurant? restaurant) {
    if (cart.isDineIn) return false;
    if (restaurant == null) return false;
    return !restaurant.allowsDelivery && !restaurant.allowsPickup;
  }

  String _syncedFulfillment(Restaurant r, CartState cart) {
    if (cart.fulfillment == 'pickup' && r.allowsPickup) return 'pickup';
    if (r.allowsDelivery) return 'delivery';
    if (r.allowsPickup) return 'pickup';
    return cart.fulfillment;
  }

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider);
    final restaurant = cart.restaurantId == null
        ? null
        : ref.read(restaurantProvider(cart.restaurantId!)).value;
    final t = context.l10n;
    if (!cart.isDineIn &&
        restaurant != null &&
        !restaurant.allowsDelivery &&
        !restaurant.allowsPickup) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.tableOnly)));
      return;
    }
    if (!cart.isDineIn && !cart.isPickup && _address.text.trim().length < 3) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.enterAddress)));
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
      Haptics.success();
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

  Future<void> _pickMap() async {
    final cart = ref.read(cartProvider);
    final line = _address.text.trim().isNotEmpty
        ? _address.text.trim()
        : cart.destLine;
    final q = <String, String>{
      if (cart.destLat != null) 'lat': '${cart.destLat}',
      if (cart.destLng != null) 'lng': '${cart.destLng}',
      if (line != null && line.isNotEmpty) 'line': line,
    };
    final uri = Uri(path: '/map/pick', queryParameters: q.isEmpty ? null : q);
    final place = await context.push<MapPlace>(uri.toString());
    if (place == null || !mounted) return;
    setState(() => _address.text = place.line);
    ref
        .read(cartProvider.notifier)
        .setDestination(lat: place.lat, lng: place.lng, line: place.line);
    ref.read(mapOriginProvider.notifier).set(place.point);
  }

  void _useSaved(Address a, L10n t) {
    setState(() => _address.text = a.display(t));
    if (a.hasPin) {
      ref
          .read(cartProvider.notifier)
          .setDestination(lat: a.lat!, lng: a.lng!, line: a.line);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final saved = ref.watch(addressesProvider).value ?? const [];
    ref.listen(addressesProvider, (_, next) {
      final def = next.value?.where((a) => a.isDefault).firstOrNull;
      if (def != null && _address.text.isEmpty) {
        _useSaved(def, context.l10n);
      }
    });
    final restaurant = cart.restaurantId == null
        ? null
        : ref.watch(restaurantProvider(cart.restaurantId!)).value;
    if (restaurant != null && !cart.isDineIn) {
      final synced = _syncedFulfillment(restaurant, cart);
      if (synced != cart.fulfillment) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(cartProvider.notifier).setFulfillment(synced);
        });
      }
    }
    final fee = (cart.isDineIn || cart.isPickup)
        ? 0.0
        : (restaurant?.deliveryFee ?? 0);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final t = context.l10n;
    if (_placedOrderId != null) return _SuccessView(orderId: _placedOrderId!);

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(t.cart)),
        body: EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: t.cartEmpty,
          hint: t.cartEmptyHint,
          action: FilledButton.tonal(
            onPressed: () => context.go('/'),
            child: Text(t.browseRestaurants),
          ),
        ),
      );
    }

    var idx = 0;
    return Scaffold(
      appBar: AppBar(title: Text(restaurant?.name ?? t.cart)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final line in cart.items.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Dismissible(
                key: ValueKey(line.item.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) {
                  Haptics.warn();
                  ref.read(cartProvider.notifier).removeAll(line.item);
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: scheme.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.delete_outline, color: scheme.onError),
                ),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                    child: Row(
                      children: [
                        DishThumb(
                          url: line.item.imageUrl,
                          size: 56,
                          radius: 12,
                        ),
                        const SizedBox(width: 12),
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
              ),
            ).stagger(idx++),
          const SizedBox(height: 8),
          if (cart.isDineIn)
            Card(
              child: ListTile(
                leading: const Icon(Icons.table_bar_outlined),
                title: Text(t.dineIn),
                subtitle: Text(t.tableQr),
              ),
            ).stagger(idx++)
          else if (restaurant != null &&
              !restaurant.allowsDelivery &&
              !restaurant.allowsPickup)
            Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code_2_outlined),
                title: Text(t.dineIn),
                subtitle: Text(t.tableOnly),
              ),
            ).stagger(idx++)
          else ...[
            if (restaurant != null &&
                restaurant.allowsDelivery &&
                restaurant.allowsPickup) ...[
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'delivery',
                    icon: const Icon(Icons.delivery_dining_outlined),
                    label: Text(t.delivery),
                  ),
                  ButtonSegment(
                    value: 'pickup',
                    icon: const Icon(Icons.storefront_outlined),
                    label: Text(t.pickup),
                  ),
                ],
                selected: {cart.fulfillment},
                onSelectionChanged: (s) =>
                    ref.read(cartProvider.notifier).setFulfillment(s.first),
              ).stagger(idx++),
              const SizedBox(height: 12),
            ],
            if (cart.isPickup)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(t.pickup),
                  subtitle: Text(t.pickupAt),
                ),
              ).stagger(idx++)
            else ...[
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
                        onPressed: () => _useSaved(a, t),
                      ),
                  ],
                ).stagger(idx++),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _address,
                decoration: InputDecoration(
                  labelText: t.deliveryAddress,
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ).stagger(idx++),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickMap,
                icon: const Icon(Icons.map_outlined),
                label: Text(t.pickAddress),
              ).stagger(idx++),
            ],
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            decoration: InputDecoration(
              labelText: cart.isDineIn || cart.isPickup
                  ? t.orderNote
                  : t.courierComment,
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
                  _Row(t.subtotal, formatMoney(cart.subtotal)),
                  if (fee > 0) _Row(t.delivery, formatMoney(fee)),
                  const Divider(height: 20),
                  _Row(t.total, formatMoney(cart.subtotal + fee), bold: true),
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
            onTap: _submitting || _blocked(cart, restaurant) ? null : _checkout,
            child: FilledButton(
              onPressed: _submitting || _blocked(cart, restaurant)
                  ? null
                  : _checkout,
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
                          Text(t.placeOrder),
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
                  context.l10n.orderPlaced(orderId),
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                )
                .animate(delay: 500.ms)
                .fadeIn(duration: Motion.normal)
                .slideY(begin: 0.3, end: 0, curve: Motion.enter),
            const SizedBox(height: 6),
            Text(context.l10n.keepYouPosted, style: text.bodyMedium)
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
