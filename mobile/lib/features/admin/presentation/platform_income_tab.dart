import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../data/stats_repository.dart';
import 'stats_widgets.dart';

/// The platform's own books, across every venue.
class PlatformIncomeTab extends ConsumerWidget {
  const PlatformIncomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final income = ref.watch(platformRevenueProvider);
    final days = ref.watch(statsWindowProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(platformRevenueProvider),
      child: income.when(
        loading: () => const ListSkeleton(count: 3, rowHeight: 110),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 60),
            Center(child: Text(errorMessage(e))),
          ],
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            WindowPicker(
              days: days,
              onPick: (value) =>
                  ref.read(statsWindowProvider.notifier).set(value),
            ),
            const SizedBox(height: 16),
            if (data.orders == 0)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.payments_outlined,
                  title: t.noStatsYet,
                  hint: t.noStatsYetHint,
                ),
              )
            else ...[
              StatGrid(
                tiles: [
                  StatTile(label: t.grossLabel, value: formatMoney(data.gross)),
                  StatTile(label: t.ordersLabel, value: '${data.orders}'),
                  StatTile(
                    label: t.courierPayoutsLabel,
                    value: formatMoney(data.courierPayouts),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Said out loud so nobody reads the difference as margin.
              Text(
                t.notProfitNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              DayChart(days: data.byDay, peak: data.peakDay),
              const SizedBox(height: 22),
              SectionTitle(t.byPlanLabel),
              for (final slice in data.byPlan)
                RankRow(
                  title: slice.planCode,
                  subtitle: '${slice.restaurants}',
                  value: moneyOrDash(slice.gross),
                ),
              if (data.topRestaurants.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionTitle(t.topVenues),
                for (final venue in data.topRestaurants)
                  RankRow(
                    title: venue.name,
                    subtitle: '${venue.orders}',
                    value: formatMoney(venue.gross),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
