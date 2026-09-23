import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';

import '../../../core/theme/buttons.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../../../core/widgets/pill_tab_bar.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/stagger.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../map/presentation/courier_locator.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/orders_screen.dart';
import 'earnings_tab.dart';

/// Courier home: pick up available orders, advance own orders.
class CourierScreen extends ConsumerWidget {
  const CourierScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final t = context.l10n;
    return CourierLocator(
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(user?.name ?? t.courier),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: t.logOut,
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
              ),
            ],
            bottom: PillTabBar(tabs: [t.available, t.myDeliveries, t.earnings]),
          ),
          body: const TabBarView(
            children: [_AvailableTab(), _MineTab(), EarningsTab()],
          ),
        ),
      ),
    );
  }
}

class _AvailableTab extends ConsumerWidget {
  const _AvailableTab();

  Future<void> _accept(BuildContext context, WidgetRef ref, int id) async {
    try {
      await ref.read(orderRepositoryProvider).accept(id);
      Haptics.success();
      ref.invalidate(availableOrdersProvider);
      ref.invalidate(ordersProvider);
      if (context.mounted) DefaultTabController.of(context).animateTo(1);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
      ref.invalidate(availableOrdersProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _OrderList(
      orders: ref.watch(availableOrdersProvider),
      empty: EmptyState(
        icon: Icons.hourglass_empty,
        title: context.l10n.noOrdersWaiting,
        hint: context.l10n.noOrdersWaitingHint,
      ),
      onRefresh: () => ref.refresh(availableOrdersProvider.future),
      action: (o) => Pressable(
        onTap: () => _accept(context, ref, o.id),
        child: FilledButton.icon(
          style: AppButtons.inline,
          onPressed: () => _accept(context, ref, o.id),
          icon: const Icon(Icons.check),
          label: Text(context.l10n.accept),
        ),
      ),
    );
  }
}

class _MineTab extends ConsumerWidget {
  const _MineTab();

  Future<void> _advance(
    BuildContext context,
    WidgetRef ref,
    Order o,
    OrderStatus next,
  ) async {
    // Closing a delivery needs the four digits the customer reads out.
    String? code;
    if (next == OrderStatus.delivered && o.channel == 'delivery') {
      code = await showDialog<String>(
        context: context,
        builder: (_) => const _HandoverDialog(),
      );
      if (code == null) return;
    }
    try {
      await ref.read(orderRepositoryProvider).advance(o.id, handoverCode: code);
      Haptics.success();
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
    // Courier's /orders returns only assigned orders; hide finished ones.
    final orders = ref
        .watch(ordersProvider)
        .whenData((list) => list.where((o) => !o.status.isFinal).toList());
    return _OrderList(
      orders: orders,
      empty: EmptyState(
        icon: Icons.delivery_dining,
        title: context.l10n.noActiveDeliveries,
        hint: context.l10n.noActiveDeliveriesHint,
      ),
      onRefresh: () => ref.refresh(ordersProvider.future),
      showChat: true,
      action: (o) {
        final next = o.status.courierNext;
        if (next == null) return const SizedBox.shrink();
        return Pressable(
          onTap: () => _advance(context, ref, o, next),
          child: FilledButton.icon(
            style: AppButtons.inline,
            onPressed: () => _advance(context, ref, o, next),
            icon: Icon(switch (next) {
              OrderStatus.preparing => Icons.restaurant,
              OrderStatus.onTheWay => Icons.two_wheeler,
              OrderStatus.delivered => Icons.done_all,
              _ => Icons.arrow_forward,
            }),
            label: Text(o.courierActionLabel(next, context.l10n)),
          ),
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
    this.showChat = false,
  });

  final AsyncValue<List<Order>> orders;
  final Widget empty;
  final Future<void> Function() onRefresh;
  final Widget Function(Order) action;
  final bool showChat;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return orders.when(
      loading: () => const ListSkeleton(rowHeight: 150),
      error: (e, _) => EmptyState(
        icon: Icons.wifi_off,
        title: context.l10n.couldNotLoad,
        hint: errorMessage(e),
      ),
      data: (list) => RefreshIndicator(
        onRefresh: onRefresh,
        child: list.isEmpty
            ? empty
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final o = list[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    o.restaurantName,
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                StatusChip(o.status),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _Line(Icons.place_outlined, o.address),
                            _Line(
                              Icons.person_outline,
                              '${o.customer.name}${o.customer.phone != null ? ' · ${o.customer.phone}' : ''}',
                            ),
                            _Line(
                              Icons.shopping_bag_outlined,
                              o.items
                                  .map((i) => '${i.quantity}× ${i.name}')
                                  .join(', '),
                            ),
                            if (o.comment != null)
                              _Line(Icons.chat_bubble_outline, o.comment!),
                            if (o.hasMap) ...[
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      context.push('/map/track/${o.id}'),
                                  icon: const Icon(Icons.map_outlined),
                                  label: Text(context.l10n.openMap),
                                ),
                              ),
                            ],
                            if (showChat) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      context.push('/chat/${o.id}'),
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: Text(context.l10n.chat),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  formatMoney(o.total),
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '  ·  #${o.id}',
                                  style: text.labelSmall?.copyWith(
                                    color: scheme.outline,
                                  ),
                                ),
                                const Spacer(),
                                action(o),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).stagger(i);
                },
              ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Asks the courier for the code the customer is holding.
class _HandoverDialog extends StatefulWidget {
  const _HandoverDialog();

  @override
  State<_HandoverDialog> createState() => _HandoverDialogState();
}

class _HandoverDialogState extends State<_HandoverDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _code.text.trim();
    if (v.length < 4) return;
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return AlertDialog(
      title: Text(t.handoverTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.handoverHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '0000',
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(
          style: AppButtons.inline,
          onPressed: _submit,
          child: Text(t.actionMarkDelivered),
        ),
      ],
    );
  }
}
