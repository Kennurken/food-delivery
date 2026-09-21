import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/money.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No orders yet'))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(ordersProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final o = list[i];
                    return Card(
                      child: ListTile(
                        onTap: () => context.push('/orders/${o.id}'),
                        title: Text('Order #${o.id} · ${formatMoney(o.total)}'),
                        subtitle: Text(
                          '${o.items.length} items · ${o.address}',
                        ),
                        trailing: StatusChip(o.status),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.delivered => Colors.green,
      OrderStatus.cancelled => Colors.red,
      OrderStatus.onTheWay => Colors.blue,
      _ => Colors.orange,
    };
    return Chip(
      label: Text(status.label, style: TextStyle(color: color, fontSize: 12)),
      side: BorderSide(color: color),
      backgroundColor: color.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
    );
  }
}
