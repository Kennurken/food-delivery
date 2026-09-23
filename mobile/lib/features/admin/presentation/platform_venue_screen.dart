import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../../../core/widgets/stagger.dart';
import '../data/admin_repository.dart';
import '../domain/platform_venue.dart';
import 'venue_settings_screen.dart';

/// One tenant in full: contacts you can actually dial, staff, and recent trade.
class PlatformVenueScreen extends ConsumerWidget {
  const PlatformVenueScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final venue = ref.watch(platformVenueProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: Text(venue.value?.name ?? t.venue),
        actions: [
          IconButton(
            tooltip: t.venueSettings,
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => VenueSettingsScreen(restaurantId: id),
              ),
            ),
          ),
        ],
      ),
      body: venue.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => EmptyState(
          icon: Icons.wifi_off,
          title: t.couldNotLoad,
          hint: errorMessage(e),
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(platformVenueProvider(id)),
            child: Text(t.retry),
          ),
        ),
        data: (v) {
          var i = 0;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(platformVenueProvider(id).future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TradeCard(v).stagger(i++),
                const SizedBox(height: 12),
                Text(
                  t.staff,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ).stagger(i++),
                const SizedBox(height: 8),
                if (v.staff.isEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person_off_outlined),
                      title: Text(t.noOwnerLinked),
                      subtitle: Text(t.noOwnerHint),
                    ),
                  ).stagger(i++)
                else
                  for (final person in v.staff)
                    _ContactCard(person).stagger(i++),
                const SizedBox(height: 16),
                Text(
                  t.recentOrders,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ).stagger(i++),
                const SizedBox(height: 8),
                if (v.recentOrders.isEmpty)
                  Card(child: ListTile(title: Text(t.noOrdersYet))).stagger(i++)
                else
                  for (final order in v.recentOrders)
                    _OrderRow(order).stagger(i++),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TradeCard extends StatelessWidget {
  const _TradeCard(this.v);

  final PlatformVenue v;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${v.cuisine} · ${v.planCode.toUpperCase()}',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  v.isOpen ? Icons.check_circle : Icons.pause_circle_outlined,
                  size: 18,
                  color: v.isOpen ? Colors.green : scheme.outline,
                ),
                const SizedBox(width: 4),
                Text(v.isOpen ? t.open : t.closed, style: text.labelMedium),
              ],
            ),
            const Divider(height: 24),
            _Row(t.ordersWindow(v.windowDays), '${v.ordersWindow}'),
            _Row(t.revenueWindow, formatMoney(v.revenueWindow)),
            _Row(t.ordersAllTime, '${v.ordersTotal}'),
            _Row(t.revenueAllTime, formatMoney(v.revenueTotal)),
            _Row(t.rating, '${v.rating} (${v.ratingCount})'),
            if (v.lastOrderAt != null)
              _Row(t.lastOrder, _short(v.lastOrderAt!)),
          ],
        ),
      ),
    );
  }

  static String _short(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _ContactCard extends StatelessWidget {
  const _ContactCard(this.person);

  final PlatformContact person;

  Future<void> _dial(String scheme, String value) async {
    await launchUrl(Uri(scheme: scheme, path: value));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final phone = person.phone;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: person.role == 'owner'
                ? scheme.primary
                : scheme.surfaceContainerHighest,
            child: Icon(
              person.role == 'owner' ? Icons.star : Icons.person_outline,
              size: 18,
              color: person.role == 'owner'
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant,
            ),
          ),
          title: Text(
            person.name,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [person.role, person.email].where((s) => s.isNotEmpty).join(' · '),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (phone != null && phone.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.phone_outlined),
                  tooltip: phone,
                  onPressed: () => _dial('tel', phone),
                ),
              if (person.email.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.mail_outline),
                  tooltip: person.email,
                  onPressed: () => _dial('mailto', person.email),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow(this.o);

  final PlatformOrderRow o;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // Cash only counts once someone took it, not the moment it was ordered.
    const settledStates = {'paid', 'collected'};
    final settled = settledStates.contains(o.payStatus);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          dense: true,
          title: Text(
            '#${o.id} · ${formatMoney(o.total)}',
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text('${o.status} · ${o.channel} · ${o.payMethod}'),
          trailing: Text(
            o.payStatus,
            style: text.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: settled ? Colors.green : scheme.outline,
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: text.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
