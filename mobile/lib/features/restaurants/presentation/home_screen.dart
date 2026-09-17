import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/money.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/presentation/cart_controller.dart';
import '../data/restaurant_repository.dart';
import '../domain/restaurant.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(restaurantsProvider);
    final cartCount = ref.watch(cartProvider.select((c) => c.count));
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${user?.name ?? ''} 👋'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Orders',
            onPressed: () => context.push('/orders'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: cartCount == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/cart'),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text('Cart · $cartCount'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search restaurants',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => ref.read(restaurantSearchProvider.notifier).set(v),
            ),
          ),
          Expanded(
            child: restaurants.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: errorMessage(e),
                onRetry: () => ref.invalidate(restaurantsProvider),
              ),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('Nothing found'))
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(restaurantsProvider.future),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _RestaurantCard(list[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  const _RestaurantCard(this.r);

  final Restaurant r;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/restaurants/${r.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 8,
              child: r.imageUrl == null
                  ? Container(color: Colors.grey.shade200, child: const Icon(Icons.restaurant, size: 48))
                  : CachedNetworkImage(
                      imageUrl: r.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(color: Colors.grey.shade200),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(r.name, style: text.titleMedium)),
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(r.rating.toStringAsFixed(1)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.cuisine} · ${r.deliveryTimeMin} min · delivery ${formatMoney(r.deliveryFee)}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}
