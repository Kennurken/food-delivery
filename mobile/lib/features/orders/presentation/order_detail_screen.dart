import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/utils/money.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';
import 'orders_screen.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.id});

  final int id;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(orderRepositoryProvider).cancel(id);
      ref.invalidate(orderProvider(id));
      ref.invalidate(ordersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(id));
    return Scaffold(
      appBar: AppBar(title: Text('Order #$id')),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (o) => RefreshIndicator(
          onRefresh: () => ref.refresh(orderProvider(id).future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Status', style: Theme.of(context).textTheme.titleMedium),
                  StatusChip(o.status),
                ],
              ),
              const SizedBox(height: 8),
              _StatusTimeline(o.status),
              const Divider(height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(o.address),
                subtitle: o.comment == null ? null : Text(o.comment!),
              ),
              const Divider(height: 32),
              for (final i in o.items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${i.quantity} × ${i.name}'),
                  trailing: Text(formatMoney(i.price * i.quantity)),
                ),
              const Divider(),
              _Row('Subtotal', formatMoney(o.subtotal)),
              _Row('Delivery', formatMoney(o.deliveryFee)),
              _Row('Total', formatMoney(o.total), bold: true),
              const SizedBox(height: 24),
              if (o.status.canCancel)
                OutlinedButton(
                  onPressed: () => _cancel(context, ref),
                  child: const Text('Cancel order'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline(this.status);

  final OrderStatus status;

  static const _steps = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.onTheWay,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) return const SizedBox.shrink();
    final idx = _steps.indexOf(status);
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i <= idx ? primary : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          if (i < _steps.length - 1) const SizedBox(width: 4),
        ],
      ],
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
