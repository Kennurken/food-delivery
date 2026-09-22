import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';

import '../../../core/theme/motion.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/stagger.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';
import 'reorder_action.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final t = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(t.myOrders)),
      body: orders.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => EmptyState(
          icon: Icons.wifi_off,
          title: t.couldNotLoad,
          hint: errorMessage(e),
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(ordersProvider),
            child: Text(t.retry),
          ),
        ),
        data: (list) {
          final active = list.where((o) => !o.status.isFinal).toList();
          final past = list.where((o) => o.status.isFinal).toList();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(ordersProvider.future),
            child: list.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: t.noOrdersYet,
                    hint: t.noOrdersHint,
                    action: FilledButton.tonal(
                      onPressed: () => context.go('/'),
                      child: Text(t.browseRestaurants),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (active.isNotEmpty) ...[
                        _Header(t.active, active.length),
                        for (final (i, o) in active.indexed)
                          _OrderCard(o).stagger(i),
                      ],
                      if (past.isNotEmpty) ...[
                        if (active.isNotEmpty) const SizedBox(height: 12),
                        _Header(t.history, past.length),
                        for (final (i, o) in past.indexed)
                          _OrderCard(o).stagger(active.length + i),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.count);

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Text(
            title,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: text.labelSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard(this.o);

  final Order o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Pressable(
              onTap: () => context.push('/orders/${o.id}'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.restaurantName,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            o.items
                                .map((i) => '${i.quantity}× ${i.name}')
                                .join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                formatMoney(o.total),
                                style: text.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '  ·  #${o.id}',
                                style: text.labelSmall?.copyWith(
                                  color: scheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(o.status, order: o),
                  ],
                ),
              ),
            ),
            if (o.status.canReorder)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: FilledButton.tonal(
                  onPressed: () => reorderOrder(context, ref, o),
                  child: Text(context.l10n.orderAgain),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.order});

  final OrderStatus status;
  final Order? order;

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
            order?.statusLabel(context.l10n) ?? status.label(context.l10n),
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
