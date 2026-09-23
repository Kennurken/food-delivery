import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../data/admin_repository.dart';

/// What this venue pays the platform.
///
/// Subscribing opens Stripe and stops there. The plan on screen only moves once
/// the subscription webhook lands, so nobody is told they are on Premium
/// because a checkout tab was opened.
class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key, required this.restaurantId});

  final int restaurantId;

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  var _busy = false;

  Future<void> _subscribe(String planCode) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await ref
          .read(adminRepositoryProvider)
          .subscribe(widget.restaurantId, planCode);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      ref.invalidate(venueBillingProvider(widget.restaurantId));
    } catch (e) {
      _complain(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final t = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(t.cancelPlanAsk),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.cancelPlan),
          ),
        ],
      ),
    );
    if (sure != true || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .cancelSubscription(widget.restaurantId);
      Haptics.success();
      ref.invalidate(venueBillingProvider(widget.restaurantId));
    } catch (e) {
      _complain(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _complain(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(errorMessage(e))));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final billing = ref.watch(venueBillingProvider(widget.restaurantId));
    final plans = ref.watch(billingPlansProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.billing)),
      body: billing.when(
        loading: () => const ListSkeleton(count: 4, rowHeight: 80),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (data.isRetrying) _Banner(t.billingRetry, tone: _Tone.warning),
            if (data.isBlocked) _Banner(t.billingBlocked, tone: _Tone.danger),
            if (!data.billingEnabled) _Banner(t.billingOff, tone: _Tone.plain),
            _CurrentCard(data: data),
            const SizedBox(height: 22),
            plans.when(
              loading: () => const ListSkeleton(count: 3, rowHeight: 72),
              error: (e, _) => Text(errorMessage(e)),
              data: (list) => Column(
                children: [
                  for (final plan in list)
                    _PlanRow(
                      plan: plan,
                      current: plan.code == data.planCode,
                      busy: _busy || !data.billingEnabled,
                      onPick: () => _subscribe(plan.code),
                    ),
                ],
              ),
            ),
            if (data.hasSubscription) ...[
              const SizedBox(height: 18),
              TextButton(
                onPressed: _busy ? null : _cancel,
                child: Text(t.cancelPlan),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _Tone { plain, warning, danger }

class _Banner extends StatelessWidget {
  const _Banner(this.text, {required this.tone});

  final String text;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = switch (tone) {
      _Tone.danger => scheme.errorContainer,
      _Tone.warning => scheme.tertiaryContainer,
      _Tone.plain => scheme.surfaceContainerHighest,
    };
    final ink = switch (tone) {
      _Tone.danger => scheme.onErrorContainer,
      _Tone.warning => scheme.onTertiaryContainer,
      _Tone.plain => scheme.onSurfaceVariant,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: TextStyle(color: ink)),
    );
  }
}

class _CurrentCard extends StatelessWidget {
  const _CurrentCard({required this.data});

  final VenueBilling data;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final renews = data.renewsAt;
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
            t.currentPlan,
            style: text.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
          ),
          Text(
            data.planName,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.billed
                ? '${formatMoney(data.monthlyPrice)}${t.perMonth}'
                : t.freePlan,
            style: text.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
          ),
          if (renews != null) ...[
            const SizedBox(height: 6),
            Text(
              t.renewsOn(
                '${renews.day.toString().padLeft(2, '0')}.'
                '${renews.month.toString().padLeft(2, '0')}.${renews.year}',
              ),
              style: text.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.plan,
    required this.current,
    required this.busy,
    required this.onPick,
  });

  final BillingPlan plan;
  final bool current;
  final bool busy;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        plan.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        plan.billed
            ? '${formatMoney(plan.monthlyPrice)}${t.perMonth}'
            : t.freePlan,
      ),
      trailing: current
          ? const Icon(Icons.check_circle)
          : plan.billed
          ? FilledButton(
              onPressed: busy ? null : onPick,
              child: Text(t.subscribe),
            )
          : null,
    );
  }
}
