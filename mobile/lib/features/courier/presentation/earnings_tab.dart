import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../../../core/widgets/sliding_number.dart';
import '../../../core/widgets/stagger.dart';
import '../data/earnings_repository.dart';
import '../domain/courier_earnings.dart';
import '../../../core/widgets/anim_icon.dart';

/// Courier wallet: earnings on one side, cash owed back on the other.
class EarningsTab extends ConsumerWidget {
  const EarningsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final async = ref.watch(earningsProvider);
    final days = ref.watch(earningsWindowProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(earningsProvider),
      child: async.when(
        loading: () => const ListSkeleton(count: 3, rowHeight: 110),
        error: (_, _) => ListView(
          children: [
            const SizedBox(height: 80),
            EmptyState(
              icon: Icons.wifi_off,
              title: t.noEarningsYet,
              hint: t.retry,
            ),
          ],
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _WindowPicker(
              days: days,
              onPick: (value) =>
                  ref.read(earningsWindowProvider.notifier).set(value),
            ).stagger(0),
            const SizedBox(height: 16),
            _EarnedCard(data: data).stagger(1),
            const SizedBox(height: 12),
            if (data.cashHeld > 0) ...[
              _CashCard(amount: data.cashHeld).stagger(2),
              const SizedBox(height: 12),
            ],
            if (data.byDay.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: EmptyState(
                  shape: AnimShape.wallet,
                  title: t.noEarningsYet,
                  hint: t.noEarningsYetHint,
                ),
              )
            else
              _DayChart(data: data).stagger(3),
            const _HistorySection(),
          ],
        ),
      ),
    );
  }
}

class _WindowPicker extends StatelessWidget {
  const _WindowPicker({required this.days, required this.onPick});

  final int days;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final options = <int, String>{7: t.days7, 30: t.days30, 90: t.days90};
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: days == entry.key,
            onSelected: (_) => onPick(entry.key),
          ),
      ],
    );
  }
}

class _EarnedCard extends StatelessWidget {
  const _EarnedCard({required this.data});

  final CourierEarnings data;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.earnedLabel,
            style: text.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 4),
          SlidingNumber(
            formatMoney(data.earned),
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          // Wrap, not Row: on a 320px phone the all-time sum in Russian ran
          // six pixels past the card. It moves to a second line instead.
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _Stat(
                label: t.deliveriesLabel,
                value: '${data.deliveries}',
                tone: scheme.onPrimaryContainer,
              ),
              if (data.rating != null)
                _Stat(
                  label: t.courierRatingLabel,
                  value: '★ ${data.rating!.toStringAsFixed(1)} (${data.rated})',
                  tone: scheme.onPrimaryContainer,
                ),
              _Stat(
                label: t.allTimeLabel,
                value: formatMoney(data.earnedAllTime),
                tone: scheme.onPrimaryContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: text.labelSmall?.copyWith(color: tone.withValues(alpha: 0.75)),
        ),
        Text(
          value,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: tone,
          ),
        ),
      ],
    );
  }
}

/// Money the courier is holding for the platform. Deliberately styled as a
/// warning rather than a second balance — it is a debt, not a reward.
class _CashCard extends StatelessWidget {
  const _CashCard({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.payments_outlined, color: scheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.cashToHandIn,
                  style: text.labelLarge?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                Text(
                  formatMoney(amount),
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.cashToHandInHint,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChart extends StatelessWidget {
  const _DayChart({required this.data});

  final CourierEarnings data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Oldest on the left reads like a calendar; the API hands them back newest first.
    final rows = data.byDay.reversed.toList(growable: false);
    final peak = data.peakDay;
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final row in rows)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      row.earned == 0 ? '' : formatMoney(row.earned),
                      style: text.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: row.earned / peak),
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      builder: (_, factor, _) => Container(
                        height: 8 + 110 * factor,
                        decoration: BoxDecoration(
                          color: row.earned == 0
                              ? scheme.surfaceContainerHighest
                              : scheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      row.shortLabel,
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Per-delivery payout history section.
class _HistorySection extends ConsumerWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final async = ref.watch(payoutHistoryProvider);

    return async.when(
      loading: () => const ListSkeleton(count: 5, rowHeight: 72),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            t.couldNotLoad,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ),
      data: (history) {
        final rows = history.rows;
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                t.noDeliveriesYet,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        final notifier = ref.read(payoutHistoryProvider.notifier);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              t.history,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length + (history.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == rows.length) {
                  // Load more button
                  return Center(
                    child: TextButton(
                      onPressed: history.loadingMore
                          ? null
                          : () => notifier.loadMore().catchError((Object e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(errorMessage(e))),
                                );
                              }
                            }),
                      child: history.loadingMore
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(t.showMore),
                    ),
                  );
                }

                final row = rows[index];
                final dateStr = _formatDateTime(row.at);
                final subtitle = row.cashHeld > 0
                    ? '$dateStr  ·  ${t.cashInHand(formatMoney(row.cashHeld))}'
                    : dateStr;

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    row.restaurantName,
                    style: text.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitle,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '+${formatMoney(row.payout)} ₸',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// `2026-09-30T12:40:00` -> `30.09 12:40`
  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d.$m $h:$min';
  }
}
