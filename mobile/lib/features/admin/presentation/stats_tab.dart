import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../../../core/widgets/stagger.dart';
import '../../restaurants/domain/restaurant.dart';
import '../data/admin_repository.dart';
import '../data/stats_repository.dart';
import '../domain/venue_stats.dart';
import 'stats_widgets.dart';
import '../../../core/widgets/anim_icon.dart';

/// A venue's own numbers, plus the people behind them.
class StatsTab extends ConsumerWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(adminRestaurantsProvider);
    return venues.when(
      loading: () => const ListSkeleton(count: 3, rowHeight: 110),
      error: (e, _) => Center(child: Text(errorMessage(e))),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.storefront_outlined,
            title: context.l10n.noStatsYet,
            hint: context.l10n.noStatsYetHint,
          );
        }
        final selected = ref.watch(statsVenueProvider) ?? list.first.id;
        return _Body(venues: list, restaurantId: selected);
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.venues, required this.restaurantId});

  final List<Restaurant> venues;
  final int restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(venueStatsProvider(restaurantId));
    final days = ref.watch(statsWindowProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(venueStatsProvider(restaurantId));
        ref.invalidate(venueCustomersProvider(restaurantId));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _VenuePicker(
            venues: venues,
            selected: restaurantId,
            onPick: (id) => ref.read(statsVenueProvider.notifier).select(id),
          ).stagger(0),
          const SizedBox(height: 12),
          WindowPicker(
            days: days,
            onPick: (value) =>
                ref.read(statsWindowProvider.notifier).set(value),
          ).stagger(1),
          const SizedBox(height: 16),
          stats.when(
            loading: () => const ListSkeleton(count: 3, rowHeight: 110),
            error: (e, _) => Text(errorMessage(e)),
            data: (data) => _Numbers(data: data, restaurantId: restaurantId),
          ),
        ],
      ),
    );
  }
}

class _VenuePicker extends StatelessWidget {
  const _VenuePicker({
    required this.venues,
    required this.selected,
    required this.onPick,
  });

  final List<Restaurant> venues;
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    if (venues.length == 1) {
      return Text(
        venues.first.name,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: selected,
      decoration: InputDecoration(
        labelText: context.l10n.pickVenue,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final venue in venues)
          DropdownMenuItem(value: venue.id, child: Text(venue.name)),
      ],
      onChanged: (value) {
        if (value != null) onPick(value);
      },
    );
  }
}

class _Numbers extends ConsumerWidget {
  const _Numbers({required this.data, required this.restaurantId});

  final VenueStats data;
  final int restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    if (data.orders == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: EmptyState(
          shape: AnimShape.chart,
          title: t.noStatsYet,
          hint: t.noStatsYetHint,
        ),
      );
    }
    final customers = ref.watch(venueCustomersProvider(restaurantId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatGrid(
          tiles: [
            StatTile(label: t.revenueLabel, value: formatMoney(data.revenue)),
            StatTile(label: t.ordersLabel, value: '${data.orders}'),
            StatTile(
              label: t.averageCheck,
              value: formatMoney(data.averageCheck),
            ),
            StatTile(
              label: t.cancelledLabel,
              value:
                  '${data.cancelled} · '
                  '${(data.cancelRate * 100).toStringAsFixed(0)}%',
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          t.planWindowNote(data.windowLimit),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        DayChart(days: data.byDay, peak: data.peakDay),
        if (data.topDishes.isNotEmpty) ...[
          const SizedBox(height: 22),
          SectionTitle(t.topDishes),
          for (final dish in data.topDishes)
            RankRow(
              title: dish.name,
              subtitle: '× ${dish.quantity}',
              value: formatMoney(dish.revenue),
            ),
        ],
        const SizedBox(height: 22),
        SectionTitle(t.customers),
        customers.when(
          loading: () => const ListSkeleton(count: 3, rowHeight: 64),
          error: (e, _) => Text(errorMessage(e)),
          data: (rows) => rows.isEmpty
              ? Text(t.noStatsYet)
              : Column(
                  children: [
                    for (final row in rows)
                      RankRow(
                        title: row.name,
                        subtitle: [
                          t.customerOrders(row.orders),
                          if (row.phone != null) row.phone!,
                        ].join(' · '),
                        value: formatMoney(row.spent),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
