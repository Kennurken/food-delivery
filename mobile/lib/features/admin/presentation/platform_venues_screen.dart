import 'dart:async';

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
import '../data/admin_repository.dart';
import '../domain/platform_venue.dart';

/// Platform-admin directory of every tenant: owner, contacts, plan, trade.
class PlatformVenuesTab extends ConsumerStatefulWidget {
  const PlatformVenuesTab({super.key});

  @override
  ConsumerState<PlatformVenuesTab> createState() => _PlatformVenuesTabState();
}

class _PlatformVenuesTabState extends ConsumerState<PlatformVenuesTab> {
  final _search = TextEditingController();
  Timer? _debounce;
  PlatformQuery _query = const PlatformQuery();

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _query = PlatformQuery(q: value, days: _query.days));
      }
    });
  }

  void _setWindow(int days) {
    setState(() => _query = PlatformQuery(q: _query.q, days: days));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final venues = ref.watch(platformVenuesProvider(_query));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: t.searchVenues,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final days in const [7, 30, 90])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t.lastDays(days)),
                    selected: _query.days == days,
                    onSelected: (_) => _setWindow(days),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: venues.when(
            loading: () => const ListSkeleton(rowHeight: 150),
            error: (e, _) => EmptyState(
              icon: Icons.wifi_off,
              title: t.couldNotLoad,
              hint: errorMessage(e),
              action: FilledButton.tonal(
                onPressed: () => ref.invalidate(platformVenuesProvider(_query)),
                child: Text(t.retry),
              ),
            ),
            data: (list) => list.isEmpty
                ? EmptyState(
                    icon: Icons.storefront_outlined,
                    title: t.nothingFound,
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.refresh(platformVenuesProvider(_query).future),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _VenueCard(list[i]).stagger(i),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard(this.v);

  final PlatformVenue v;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: () => context.push('/admin/platform/restaurants/${v.id}'),
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
                        v.name,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _Tag(
                      v.isOpen ? t.open : t.closed,
                      v.isOpen ? Colors.green : scheme.outline,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Tag(v.planCode.toUpperCase(), scheme.primary),
                    _Tag(
                      v.billingStatus,
                      v.billingStatus == 'active'
                          ? Colors.green
                          : Colors.orange,
                    ),
                    _Tag(v.cuisine, scheme.tertiary),
                  ],
                ),
                const Divider(height: 22),
                if (v.owner != null)
                  _OwnerLine(v.owner!)
                else
                  Row(
                    children: [
                      Icon(
                        Icons.person_off_outlined,
                        size: 16,
                        color: scheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.noOwnerLinked,
                        style: text.bodySmall?.copyWith(color: scheme.error),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Metric(t.ordersWindow(v.windowDays), '${v.ordersWindow}'),
                    _Metric(t.revenueWindow, formatMoney(v.revenueWindow)),
                    _Metric(t.staff, '${v.staffCount}'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerLine extends StatelessWidget {
  const _OwnerLine(this.owner);

  final PlatformContact owner;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            owner.name.isEmpty
                ? '?'
                : owner.name.characters.first.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                owner.name,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                [owner.phone, owner.email].whereType<String>().join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: Motion.fast,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}
