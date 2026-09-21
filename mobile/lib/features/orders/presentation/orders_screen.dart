import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/stagger.dart';
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Pressable(
                        onTap: () => context.push('/orders/${o.id}'),
                        child: Card(
                          child: ListTile(
                            title: Text(
                              '${o.restaurantName} · ${formatMoney(o.total)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '#${o.id} · ${o.items.length} items · ${o.address}',
                            ),
                            trailing: StatusChip(o.status),
                          ),
                        ),
                      ),
                    ).stagger(i);
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
    return AnimatedContainer(
      duration: Motion.normal,
      curve: Motion.enter,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
