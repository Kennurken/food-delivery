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
import '../../../core/widgets/stagger.dart';
import '../../../core/widgets/stretch_switch.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/orders_screen.dart';
import '../data/admin_repository.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.admin),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
          bottom: PillTabBar(tabs: [t.orders, t.restaurants]),
        ),
        body: const TabBarView(children: [_OrdersTab(), _RestaurantsTab()]),
      ),
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    Order o,
    OrderStatus s,
  ) async {
    try {
      await ref.read(orderRepositoryProvider).setStatus(o.id, s);
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
    // Admin's /orders returns everything; active first.
    final orders = ref.watch(ordersProvider).whenData((list) {
      final active = list.where((o) => !o.status.isFinal).toList();
      final done = list.where((o) => o.status.isFinal).toList();
      return [...active, ...done];
    });
    return orders.when(
      loading: () => const ListSkeleton(rowHeight: 140),
      error: (e, _) => Center(child: Text(errorMessage(e))),
      data: (list) => RefreshIndicator(
        onRefresh: () => ref.refresh(ordersProvider.future),
        child: list.isEmpty
            ? EmptyState(
                icon: Icons.inbox_outlined,
                title: context.l10n.noOrdersYet,
                hint: context.l10n.noOrdersAdminHint,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final o = list[i];
                  final text = Theme.of(context).textTheme;
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
                                    '#${o.id} · ${o.restaurantName} · ${formatMoney(o.total)}',
                                    style: text.titleMedium,
                                  ),
                                ),
                                StatusChip(o.status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('${o.customer.name} · ${o.address}'),
                            Text(
                              o.items
                                  .map((i) => '${i.quantity}× ${i.name}')
                                  .join(', '),
                              style: text.bodySmall,
                            ),
                            if (o.courier != null)
                              Text(
                                '${context.l10n.courier}: ${o.courier!.name}',
                                style: text.bodySmall,
                              ),
                            if (o.status.adminNext.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (final s in o.status.adminNext) ...[
                                    if (s == OrderStatus.cancelled)
                                      OutlinedButton(
                                        style: AppButtons.inline,
                                        onPressed: () =>
                                            _set(context, ref, o, s),
                                        child: Text(
                                          s.actionLabel(context.l10n),
                                        ),
                                      )
                                    else
                                      Expanded(
                                        child: FilledButton.tonal(
                                          style: AppButtons.inline,
                                          onPressed: () =>
                                              _set(context, ref, o, s),
                                          child: Text(
                                            s.actionLabel(context.l10n),
                                          ),
                                        ),
                                      ),
                                    if (s != o.status.adminNext.last)
                                      const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ],
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

class _RestaurantsTab extends ConsumerWidget {
  const _RestaurantsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(adminRestaurantsProvider);
    return restaurants.when(
      loading: () => const ListSkeleton(),
      error: (e, _) => Center(child: Text(errorMessage(e))),
      data: (list) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final r = list[i];
          // Row tap opens the menu; only the switch toggles is_open.
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: Text(r.name),
                subtitle: Text(
                  '${r.cuisine} · ${context.l10n.deliveryFee(formatMoney(r.deliveryFee))} · ${r.isOpen ? context.l10n.open : context.l10n.closed}',
                ),
                onTap: () => context.push('/admin/restaurants/${r.id}'),
                trailing: StretchSwitch(
                  value: r.isOpen,
                  onChanged: (v) async {
                    try {
                      await ref.read(adminRepositoryProvider).updateRestaurant(
                        r.id,
                        {'is_open': v},
                      );
                      ref.invalidate(adminRestaurantsProvider);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(errorMessage(e))),
                        );
                      }
                    }
                  },
                ),
              ),
            ),
          ).stagger(i);
        },
      ),
    );
  }
}
