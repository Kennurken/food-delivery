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
import 'platform_applications_tab.dart';
import 'platform_cities_tab.dart';
import 'platform_income_tab.dart';
import 'platform_venues_screen.dart';
import 'stats_tab.dart';
import '../../../core/widgets/anim_icon.dart';

/// Where `/admin?tab=` lands: a top tab and, under Platform, its sub-tab.
/// Unknown names land nowhere in particular (the screen opens as usual).
({int top, int platform})? adminTabFor(String? tab) => switch (tab) {
  'orders' => (top: 0, platform: 0),
  'restaurants' => (top: 1, platform: 0),
  'statistics' => (top: 2, platform: 0),
  'platform' || 'overview' => (top: 3, platform: 0),
  'directory' => (top: 3, platform: 1),
  'income' => (top: 3, platform: 2),
  'cities' => (top: 3, platform: 3),
  'applications' => (top: 3, platform: 4),
  _ => null,
};

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key, this.tab});

  /// Tab to show, from `/admin?tab=` (a push about a new application opens
  /// `applications`). See [adminTabFor].
  final String? tab;

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with TickerProviderStateMixin {
  // Owned here rather than by DefaultTabControllers so a deep link can switch
  // tabs on a screen that is already open.
  late final TabController _top;
  late final TabController _platform;

  @override
  void initState() {
    super.initState();
    final at = adminTabFor(widget.tab);
    _top = TabController(length: 4, vsync: this, initialIndex: at?.top ?? 0);
    _platform = TabController(
      length: 5,
      vsync: this,
      initialIndex: at?.platform ?? 0,
    );
    _consumeTab();
  }

  @override
  void didUpdateWidget(AdminScreen old) {
    super.didUpdateWidget(old);
    if (widget.tab == old.tab) return;
    final at = adminTabFor(widget.tab);
    if (at != null) {
      _top.animateTo(at.top);
      _platform.animateTo(at.platform);
    }
    _consumeTab();
  }

  /// The tab is a one-shot instruction. Dropping it from the address means a
  /// second push for the same tab is a new location, so it switches again
  /// after the admin has wandered off; the page (and these controllers) stay.
  void _consumeTab() {
    if (widget.tab == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GoRouter.maybeOf(context)?.go('/admin');
    });
  }

  @override
  void dispose() {
    _top.dispose();
    _platform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.admin),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: t.logOut,
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
        bottom: PillTabBar(
          controller: _top,
          tabs: [t.orders, t.restaurants, t.statistics, t.platform],
        ),
      ),
      body: TabBarView(
        controller: _top,
        children: [
          const _OrdersTab(),
          const _RestaurantsTab(),
          const StatsTab(),
          _PlatformTab(controller: _platform),
        ],
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
                shape: AnimShape.bag,
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
                          '${r.cuisine} · ${r.planCode ?? 'pro'} · ${context.l10n.deliveryFee(formatMoney(r.deliveryFee))} · ${r.isPending
                              ? context.l10n.pendingApproval
                              : r.isRejected
                              ? context.l10n.rejectedVenue
                              : (r.isOpen ? context.l10n.open : context.l10n.closed)}',
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

/// Platform surface: the headline numbers, then the tenant directory.
class _PlatformTab extends StatelessWidget {
  const _PlatformTab({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Column(
      children: [
        TabBar(
          controller: controller,
          isScrollable: true,
          tabs: [
            Tab(text: t.overview),
            Tab(text: t.directory),
            Tab(text: t.income),
            Tab(text: t.cities),
            Tab(text: t.applications),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: const [
              _PlatformOverview(),
              PlatformVenuesTab(),
              PlatformIncomeTab(),
              PlatformCitiesTab(),
              PlatformApplicationsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlatformOverview extends ConsumerWidget {
  const _PlatformOverview();

  Future<void> _sendTestError(BuildContext context, WidgetRef ref) async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminRepositoryProvider).sendTestError();
      messenger.showSnackBar(SnackBar(content: Text(t.testErrorSent)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

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
              // The overview reports the live provider; saying "not connected"
              // while Stripe is taking cards would be a lie on the dashboard.
              Text(
                (d['billing'] as String? ?? 'unconfigured') == 'unconfigured'
                    ? t.billingUnconfigured
                    : t.billingConnected('${d['billing']}'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                d['error_reporting'] == true
                    ? t.errorReportingOn
                    : t.errorReportingOff,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (d['error_reporting'] == true)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _sendTestError(context, ref),
                    child: Text(t.sendTestError),
                  ),
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
