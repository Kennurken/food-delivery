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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.admin),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: t.logOut,
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
          bottom: PillTabBar(tabs: [t.orders, t.restaurants, t.platform]),
        ),
        body: const TabBarView(
          children: [_OrdersTab(), _RestaurantsTab(), _PlatformTab()],
        ),
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
                                StatusChip(o.status, order: o),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${o.customer.name} · ${o.address} · ${o.channelLabel(context.l10n)}',
                            ),
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
                            if (o.kitchenNext.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (final s in o.kitchenNext) ...[
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
                                            o.nextActionLabel(s, context.l10n),
                                          ),
                                        ),
                                      ),
                                    if (s != o.kitchenNext.last)
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

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _RestaurantDialog(),
    );
    if (data == null || !context.mounted) return;
    try {
      await ref.read(adminRepositoryProvider).createRestaurant(data);
      Haptics.success();
      ref.invalidate(adminRestaurantsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(adminRestaurantsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.newRestaurant),
      ),
      body: restaurants.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.storefront_outlined,
                title: context.l10n.noRestaurants,
                hint: context.l10n.noRestaurantsHint,
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
                          '${r.cuisine} · ${r.planCode ?? 'pro'} · ${context.l10n.deliveryFee(formatMoney(r.deliveryFee))} · ${r.isOpen ? context.l10n.open : context.l10n.closed}',
                        ),
                        onTap: () => context.push('/admin/restaurants/${r.id}'),
                        trailing: StretchSwitch(
                          value: r.isOpen,
                          onChanged: (v) async {
                            try {
                              await ref
                                  .read(adminRepositoryProvider)
                                  .updateRestaurant(r.id, {'is_open': v});
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
      ),
    );
  }
}

class _RestaurantDialog extends StatefulWidget {
  const _RestaurantDialog();

  @override
  State<_RestaurantDialog> createState() => _RestaurantDialogState();
}

class _RestaurantDialogState extends State<_RestaurantDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cuisine = TextEditingController();
  final _desc = TextEditingController();
  final _fee = TextEditingController(text: '500');
  final _eta = TextEditingController(text: '30');

  @override
  void dispose() {
    for (final c in [_name, _cuisine, _desc, _fee, _eta]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return AlertDialog(
      title: Text(t.newRestaurant),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: t.name),
                validator: (v) =>
                    v != null && v.trim().isNotEmpty ? null : t.required,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cuisine,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: t.cuisine),
                validator: (v) =>
                    v != null && v.trim().isNotEmpty ? null : t.required,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _desc,
                decoration: InputDecoration(labelText: t.description),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _fee,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t.deliveryFeeTenge),
                validator: (v) => (double.tryParse(v ?? '') ?? -1) >= 0
                    ? null
                    : t.mustBePositive,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _eta,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t.etaMinutes),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 1) return t.mustBePositive;
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context, {
              'name': _name.text.trim(),
              'cuisine': _cuisine.text.trim(),
              'description': _desc.text.trim(),
              'delivery_fee': double.parse(_fee.text),
              'delivery_time_min': int.parse(_eta.text),
            });
          },
          child: Text(t.save),
        ),
      ],
    );
  }
}

class _PlatformTab extends ConsumerWidget {
  const _PlatformTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(platformOverviewProvider);
    final t = context.l10n;
    return overview.when(
      loading: () => const ListSkeleton(),
      error: (e, _) => Center(child: Text(errorMessage(e))),
      data: (d) {
        final plans = Map<String, dynamic>.from(d['plans'] as Map? ?? {});
        return RefreshIndicator(
          onRefresh: () => ref.refresh(platformOverviewProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Stat(t.venues, '${d['restaurants'] ?? 0}'),
              _Stat(t.ordersToday, '${d['orders_today'] ?? 0}'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: Text(t.plan),
                  subtitle: Text(
                    plans.isEmpty
                        ? '—'
                        : plans.entries
                              .map((e) => '${e.key} ${e.value}')
                              .join(' · '),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t.billingUnconfigured,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: Text(label, style: text.titleMedium)),
              Text(
                value,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
