import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/utils/money.dart';
import '../domain/venue_stats.dart';

/// Pieces shared by the venue dashboard and the platform books, so the two
/// surfaces cannot drift into looking like different products.

class StatTile {
  const StatTile({required this.label, required this.value, this.change});

  final String label;
  final String value;

  /// Percent change against the previous window, or null for none.
  final double? change;
}

/// "+12 %" / "−5 %", with the sign spelled out so a flat "0 %" isn't a guess.
String formatChange(double pct) {
  final sign = pct > 0 ? '+' : (pct < 0 ? '−' : '');
  final n = pct.abs();
  return '$sign${n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(1)} %';
}

class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles, this.compareDays = 0});

  final List<StatTile> tiles;

  /// Length of the window the tiles' [StatTile.change] compares against.
  final int compareDays;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final tile in tiles)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 150),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tile.label,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tile.value,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (tile.change case final pct?)
                    Text(
                      context.l10n.vsPrevious(formatChange(pct), compareDays),
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pct < 0 ? scheme.error : Colors.green.shade700,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class RankRow extends StatelessWidget {
  const RankRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class WindowPicker extends StatelessWidget {
  const WindowPicker({super.key, required this.days, required this.onPick});

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

/// Bars, oldest on the left. The API hands days back newest first because that
/// is what a list wants; a chart reads like a calendar.
///
/// Heights come from the box it is given rather than from constants: a fixed
/// 170 with fixed bar heights overflowed on a 320px phone, and would again the
/// moment someone turns large type on.
class DayChart extends StatelessWidget {
  const DayChart({
    super.key,
    required this.days,
    required this.peak,
    this.height = 170,
  });

  final List<StatsDay> days;
  final double peak;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final rows = days.reversed.toList(growable: false);
    // The label gets a box that grows with the reader's text size, and shrinks
    // its glyphs to fit rather than pushing the bars off the bottom.
    final labelBox = MediaQuery.textScalerOf(context)
        .scale(16)
        .clamp(14.0, 34.0);
    const gap = 6.0;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (_, box) {
          final barMax = (box.maxHeight - labelBox - gap).clamp(
            8.0,
            box.maxHeight,
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final row in rows)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: (row.revenue / peak).clamp(0, 1),
                          ),
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                          builder: (_, factor, _) => Container(
                            height: 6 + (barMax - 6) * factor,
                            decoration: BoxDecoration(
                              color: row.revenue == 0
                                  ? scheme.surfaceContainerHighest
                                  : scheme.primary,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                        const SizedBox(height: gap),
                        SizedBox(
                          height: labelBox,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              row.shortLabel,
                              maxLines: 1,
                              style: text.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Orders by hour of the day: 24 thin bars, the busiest tallest. Only the
/// hours a venue could plausibly be open are labelled, so the axis reads at
/// 320px.
class HourChart extends StatelessWidget {
  const HourChart({super.key, required this.hours, required this.peak});

  final List<int> hours;
  final int peak;

  static const _labelled = {0, 6, 12, 18, 23};

  @override
  Widget build(BuildContext context) {
    if (hours.length != 24 || hours.every((n) => n == 0)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var h = 0; h < 24; h++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 4 + 68 * (hours[h] / peak).clamp(0, 1),
                      decoration: BoxDecoration(
                        color: hours[h] == 0
                            ? scheme.surfaceContainerHighest
                            : scheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 14,
                      child: _labelled.contains(h)
                          ? FittedBox(
                              child: Text(
                                '$h',
                                style: text.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : null,
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

String moneyOrDash(double value) => value == 0 ? '—' : formatMoney(value);
