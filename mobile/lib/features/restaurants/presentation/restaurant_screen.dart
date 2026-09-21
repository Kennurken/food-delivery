import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/money.dart';
import '../../cart/presentation/cart_controller.dart';
import '../data/restaurant_repository.dart';
import '../domain/menu_item.dart';

class RestaurantScreen extends ConsumerWidget {
  const RestaurantScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = ref.watch(restaurantProvider(id));
    final cart = ref.watch(cartProvider);

    return Scaffold(
      body: restaurant.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (r) {
          final byCategory = <String, List<MenuItem>>{};
          for (final m in r.menu) {
            byCategory.putIfAbsent(m.category, () => []).add(m);
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(r.name),
                  background: r.imageUrl == null
                      ? null
                      : CachedNetworkImage(
                          imageUrl: r.imageUrl!,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.list(
                  children: [
                    Text(r.description),
                    const SizedBox(height: 4),
                    Text(
                      '${r.cuisine} · ⭐ ${r.rating} · ${r.deliveryTimeMin} min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    for (final entry in byCategory.entries) ...[
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      for (final m in entry.value) _MenuTile(m),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: cart.isEmpty || cart.restaurantId != id
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => context.push('/cart'),
                  child: Text(
                    'View cart · ${cart.count} · ${formatMoney(cart.subtotal)}',
                  ),
                ),
              ),
            ),
    );
  }
}

class _MenuTile extends ConsumerWidget {
  const _MenuTile(this.item);

  final MenuItem item;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider.notifier);
    if (cart.add(item)) return;

    final replace = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start a new cart?'),
        content: const Text('Your cart has items from another restaurant.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (replace == true) {
      cart.clear();
      cart.add(item);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = ref.watch(
      cartProvider.select((c) => c.items[item.id]?.quantity ?? 0),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item.name),
        subtitle: Text('${item.description}\n${formatMoney(item.price)}'),
        isThreeLine: true,
        enabled: item.isAvailable,
        trailing: qty == 0
            ? IconButton.filled(
                onPressed: item.isAvailable ? () => _add(context, ref) : null,
                icon: const Icon(Icons.add),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () =>
                        ref.read(cartProvider.notifier).remove(item),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$qty', style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    onPressed: () => _add(context, ref),
                    icon: const Icon(Icons.add_circle),
                  ),
                ],
              ),
      ),
    );
  }
}
