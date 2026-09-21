import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/money.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/orders_screen.dart';
import '../data/admin_repository.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Orders'), Tab(text: 'Restaurants')]),
        ),
        body: const TabBarView(children: [_OrdersTab(), _RestaurantsTab()]),
      ),
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  Future<void> _set(BuildContext context, WidgetRef ref, Order o, OrderStatus s) async {
    try {
      await ref.read(orderRepositoryProvider).setStatus(o.id, s);
      ref.invalidate(ordersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Admin's /orders returns everything; active first.
    final orders = ref.watch(ordersProvider).whenData((list) {
      final active = list.where((o) => !o.status.isFinal).toList();
      final done = list.where((o) => o.status.isFinal).toList();
      return [...active, ...done];
    });
    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(errorMessage(e))),
      data: (list) => RefreshIndicator(
        onRefresh: () => ref.refresh(ordersProvider.future),
        child: list.isEmpty
            ? ListView(children: const [SizedBox(height: 200, child: Center(child: Text('No orders')))])
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final o = list[i];
                  final text = Theme.of(context).textTheme;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('#${o.id} · ${o.restaurantName} · ${formatMoney(o.total)}',
                                    style: text.titleMedium),
                              ),
                              StatusChip(o.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${o.customer.name} · ${o.address}'),
                          Text(
                            o.items.map((i) => '${i.quantity}× ${i.name}').join(', '),
                            style: text.bodySmall,
                          ),
                          if (o.courier != null)
                            Text('Courier: ${o.courier!.name}', style: text.bodySmall),
                          if (o.status.adminNext.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final s in o.status.adminNext)
                                  s == OrderStatus.cancelled
                                      ? OutlinedButton(
                                          onPressed: () => _set(context, ref, o, s),
                                          child: Text(s.actionLabel),
                                        )
                                      : FilledButton.tonal(
                                          onPressed: () => _set(context, ref, o, s),
                                          child: Text(s.actionLabel),
                                        ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _RestaurantsTab extends ConsumerWidget {
  const _RestaurantsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(adminRestaurantsProvider);
    return restaurants.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(errorMessage(e))),
      data: (list) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final r = list[i];
          // Row tap opens the menu; only the switch toggles is_open.
          return Card(
            child: ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: Text(r.name),
              subtitle: Text('${r.cuisine} · delivery ${formatMoney(r.deliveryFee)} · ${r.isOpen ? 'open' : 'closed'}'),
              onTap: () => context.push('/admin/restaurants/${r.id}'),
              trailing: Switch(
                value: r.isOpen,
                onChanged: (v) async {
                  try {
                    await ref.read(adminRepositoryProvider).updateRestaurant(r.id, {'is_open': v});
                    ref.invalidate(adminRestaurantsProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
                    }
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
