import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/buttons.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/orders_screen.dart';

class KitchenScreen extends ConsumerWidget {
  const KitchenScreen({super.key, required this.restaurantId});

  final int restaurantId;

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    Order o,
    OrderStatus s,
  ) async {
    try {
      await ref.read(orderRepositoryProvider).setStatus(o.id, s);
      Haptics.success();
      ref.invalidate(kitchenOrdersProvider(restaurantId));
      ref.invalidate(ordersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final tickets = ref.watch(kitchenOrdersProvider(restaurantId));
    return Scaffold(
      appBar: AppBar(title: Text(t.kitchen)),
      body: tickets.when(
        loading: () => const ListSkeleton(rowHeight: 140),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (list) {
          final open = list.where((o) => !o.status.isFinal).toList();
          List<Order> lane(Set<OrderStatus> statuses) {
            final rows = open.where((o) => statuses.contains(o.status)).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return rows;
          }

          final incoming = lane({OrderStatus.pending, OrderStatus.confirmed});
          final cooking = lane({OrderStatus.preparing});
          final ready = lane({OrderStatus.onTheWay});
          return LayoutBuilder(
            builder: (context, c) {
              const gap = 10.0;
              final colW = c.maxWidth >= 720
                  ? (c.maxWidth - 32 - gap * 2) / 3
                  : math.max(260.0, c.maxWidth - 48);
              return ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  _Lane(
                    width: colW,
                    title: t.kitchenNew,
                    count: incoming.length,
                    orders: incoming,
                    onSet: (o, s) => _set(context, ref, o, s),
                  ),
                  const SizedBox(width: gap),
                  _Lane(
                    width: colW,
                    title: t.kitchenCooking,
                    count: cooking.length,
                    orders: cooking,
                    onSet: (o, s) => _set(context, ref, o, s),
                  ),
                  const SizedBox(width: gap),
                  _Lane(
                    width: colW,
                    title: t.kitchenReady,
                    count: ready.length,
                    orders: ready,
                    onSet: (o, s) => _set(context, ref, o, s),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    required this.width,
    required this.title,
    required this.count,
    required this.orders,
    required this.onSet,
  });

  final double width;
  final String title;
  final int count;
  final List<Order> orders;
  final void Function(Order order, OrderStatus status) onSet;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                Text(
                  title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: text.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: orders.isEmpty
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, top: 8),
                      child: Text(
                        '—',
                        style: text.bodyLarge?.copyWith(color: scheme.outline),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (_, i) => _Ticket(orders[i], onSet: onSet),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket(this.o, {required this.onSet});

  final Order o;
  final void Function(Order order, OrderStatus status) onSet;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final text = Theme.of(context).textTheme;
    final next = o.kitchenNext.where((s) => s != OrderStatus.cancelled);
    final canCancel = o.kitchenNext.contains(OrderStatus.cancelled);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${o.id} · ${_clock(o.createdAt)} · ${formatMoney(o.total)}',
                      style: text.titleMedium,
                    ),
                  ),
                  StatusChip(o.status, order: o),
                ],
              ),
              const SizedBox(height: 4),
              Text('${o.channelLabel(t)} · ${o.customer.name} · ${o.address}'),
              Text(
                o.items.map((i) => '${i.quantity}× ${i.name}').join(', '),
                style: text.bodySmall,
              ),
              if (o.kitchenNext.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final s in next) ...[
                      Expanded(
                        child: FilledButton.tonal(
                          style: AppButtons.inline,
                          onPressed: () => onSet(o, s),
                          child: Text(o.nextActionLabel(s, t)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (canCancel)
                      OutlinedButton(
                        style: AppButtons.inline,
                        onPressed: () => onSet(o, OrderStatus.cancelled),
                        child: Text(OrderStatus.cancelled.actionLabel(t)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _clock(DateTime t) {
  final l = t.toLocal();
  final h = l.hour.toString().padLeft(2, '0');
  final m = l.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
