import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/money.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/orders_screen.dart';

/// Courier home: pick up available orders, advance own orders.
class CourierScreen extends ConsumerWidget {
  const CourierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Courier · ${user?.name ?? ''}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Available'), Tab(text: 'My deliveries')]),
        ),
        body: const TabBarView(children: [_AvailableTab(), _MineTab()]),
      ),
    );
  }
}

class _AvailableTab extends ConsumerWidget {
  const _AvailableTab();

  Future<void> _accept(BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref.read(orderRepositoryProvider).accept(id);
      ref.invalidate(availableOrdersProvider);
      ref.invalidate(ordersProvider);
      if (context.mounted) DefaultTabController.of(context).animateTo(1);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
      ref.invalidate(availableOrdersProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(availableOrdersProvider);
    return _OrderList(
      orders: orders,
      empty: 'No orders waiting',
      onRefresh: () => ref.refresh(availableOrdersProvider.future),
      action: (o) => FilledButton.tonal(
        onPressed: () => _accept(context, ref, o.id),
        child: const Text('Accept'),
      ),
    );
  }
}

class _MineTab extends ConsumerWidget {
  const _MineTab();

  Future<void> _advance(BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref.read(orderRepositoryProvider).advance(id);
      ref.invalidate(ordersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Courier's /orders returns only assigned orders; hide finished ones.
    final orders = ref.watch(ordersProvider).whenData(
          (list) => list.where((o) => !o.status.isFinal).toList(),
        );
    return _OrderList(
      orders: orders,
      empty: 'No active deliveries',
      onRefresh: () => ref.refresh(ordersProvider.future),
      action: (o) {
        final next = o.status.courierNext;
        if (next == null) return const SizedBox.shrink();
        return FilledButton(
          onPressed: () => _advance(context, ref, o.id),
          child: Text(next.actionLabel),
        );
      },
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.empty,
    required this.onRefresh,
    required this.action,
  });

  final AsyncValue<List<Order>> orders;
  final String empty;
  final Future<void> Function() onRefresh;
  final Widget Function(Order) action;

  @override
  Widget build(BuildContext context) {
    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(errorMessage(e))),
      data: (list) => RefreshIndicator(
        onRefresh: onRefresh,
        child: list.isEmpty
            ? ListView(children: [SizedBox(height: 200, child: Center(child: Text(empty)))])
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final o = list[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('Order #${o.id} · ${formatMoney(o.total)}',
                                    style: Theme.of(context).textTheme.titleMedium),
                              ),
                              StatusChip(o.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(o.address),
                          Text(
                            o.items.map((i) => '${i.quantity}× ${i.name}').join(', '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Align(alignment: Alignment.centerRight, child: action(o)),
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
