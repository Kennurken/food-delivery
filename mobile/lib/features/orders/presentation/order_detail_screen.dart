import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';

import '../../../core/theme/motion.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/stagger.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';
import 'orders_screen.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.id});

  final int id;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final t = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.cancelOrderTitle),
        content: Text(t.cancelOrderBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.keep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.cancelOrder),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(orderRepositoryProvider).cancel(id);
      ref.invalidate(orderLiveProvider(id));
      ref.invalidate(ordersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  Future<void> _rate(BuildContext context, WidgetRef ref, int stars) async {
    try {
      Haptics.success();
      await ref.read(orderRepositoryProvider).rate(id, stars);
      ref.invalidate(orderLiveProvider(id));
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
    final order = ref.watch(orderLiveProvider(id));
    final t = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.orderN(id))),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (o) {
          var idx = 0;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(orderLiveProvider(id)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              o.restaurantName,
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: Motion.normal,
                              transitionBuilder: (c, a) => ScaleTransition(
                                scale: CurvedAnimation(
                                  parent: a,
                                  curve: Motion.pop,
                                ),
                                child: FadeTransition(opacity: a, child: c),
                              ),
                              child: StatusChip(
                                o.status,
                                key: ValueKey(o.status),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _StatusTimeline(o.status),
                        const SizedBox(height: 6),
                        Text(
                          o.status.hint(t),
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).stagger(idx++),
                if (o.courier != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(
                          Icons.delivery_dining,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        o.courier!.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(o.courier!.phone ?? t.courier),
                      trailing: o.courier!.phone == null
                          ? null
                          : IconButton.filledTonal(
                              icon: const Icon(Icons.phone_outlined),
                              tooltip: t.callCourier,
                              onPressed: () => launchUrl(
                                Uri(scheme: 'tel', path: o.courier!.phone),
                              ),
                            ),
                    ),
                  ).stagger(idx++),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(o.address),
                        subtitle: o.comment == null ? null : Text(o.comment!),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      for (final i in o.items)
                        ListTile(
                          dense: true,
                          leading: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${i.quantity}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(i.name),
                          trailing: Text(formatMoney(i.price * i.quantity)),
                        ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: Column(
                          children: [
                            _Row(t.subtotal, formatMoney(o.subtotal)),
                            _Row(t.delivery, formatMoney(o.deliveryFee)),
                            _Row(t.total, formatMoney(o.total), bold: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).stagger(idx++),
                const SizedBox(height: 20),
                if (o.status.canCancel)
                  OutlinedButton(
                    onPressed: () => _cancel(context, ref),
                    child: Text(t.cancelOrder),
                  ).stagger(idx++),
                if (o.status == OrderStatus.delivered)
                  _RatingRow(
                    rating: o.rating,
                    onRate: (stars) => _rate(context, ref, stars),
                  ).stagger(idx++),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RatingRow extends StatefulWidget {
  const _RatingRow({required this.rating, required this.onRate});

  final int? rating;
  final ValueChanged<int> onRate;

  @override
  State<_RatingRow> createState() => _RatingRowState();
}

class _RatingRowState extends State<_RatingRow> {
  int _hover = 0;

  @override
  Widget build(BuildContext context) {
    final done = widget.rating != null;
    final shown = widget.rating ?? _hover;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              done ? context.l10n.thanksForRating : context.l10n.howWasIt,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  Pressable(
                    scale: 0.8,
                    onTap: done
                        ? null
                        : () {
                            setState(() => _hover = i);
                            widget.onRate(i);
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child:
                          Icon(
                                i <= shown
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: const Color(0xFFF5A623),
                                size: 40,
                              )
                              .animate(
                                key: ValueKey('$i-${i <= shown}'),
                                target: i <= shown ? 1 : 0,
                              )
                              .scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.25, 1.25),
                                duration: 180.ms,
                                curve: Curves.easeOut,
                              )
                              .then()
                              .scale(
                                begin: const Offset(1, 1),
                                end: const Offset(0.8, 0.8),
                                duration: 180.ms,
                                curve: Motion.pop,
                              ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Segments fill left→right; the active one pulses (jitter "Animated Progress Bar").
class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline(this.status);

  final OrderStatus status;

  static const _steps = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.onTheWay,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (status == OrderStatus.cancelled) {
      return Container(
        height: 6,
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }
    final idx = _steps.indexOf(status);
    final done = status == OrderStatus.delivered;
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          Expanded(
            child:
                TweenAnimationBuilder<double>(
                      tween: Tween(end: i <= idx ? 1 : 0),
                      duration: Motion.slow,
                      curve: Motion.emphasized,
                      builder: (_, t, _) => Stack(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: t,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: done ? Colors.green : scheme.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate(
                      target: i == idx && !done ? 1 : 0,
                      onPlay: (c) => c.repeat(reverse: true),
                    )
                    .fade(begin: 1, end: 0.45, duration: 900.ms),
          ),
          if (i < _steps.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
