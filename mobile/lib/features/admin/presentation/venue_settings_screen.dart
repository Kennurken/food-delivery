import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../data/admin_repository.dart';

const _plans = ['basic', 'pro', 'premium'];

/// Platform settings for one venue: its plan, the limits that plan carries,
/// and per-feature overrides.
///
/// A flag is shown in three states rather than two. "By plan" is not the same
/// as "off": forcing a flag off and inheriting it off look identical in a
/// switch, and only one of them follows a later plan change.
class VenueSettingsScreen extends ConsumerStatefulWidget {
  const VenueSettingsScreen({super.key, required this.restaurantId});

  final int restaurantId;

  @override
  ConsumerState<VenueSettingsScreen> createState() =>
      _VenueSettingsScreenState();
}

class _VenueSettingsScreenState extends ConsumerState<VenueSettingsScreen> {
  var _busy = false;

  Future<void> _run(Future<void> Function(AdminRepository repo) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(adminRepositoryProvider));
      Haptics.success();
      ref.invalidate(venueSettingsProvider(widget.restaurantId));
      ref.invalidate(adminRestaurantProvider(widget.restaurantId));
      ref.invalidate(adminRestaurantsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final settings = ref.watch(venueSettingsProvider(widget.restaurantId));
    return Scaffold(
      appBar: AppBar(title: Text(t.venueSettings)),
      body: settings.when(
        loading: () => const ListSkeleton(count: 5, rowHeight: 64),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _Heading(t.planLabel),
            Wrap(
              spacing: 8,
              children: [
                for (final plan in _plans)
                  ChoiceChip(
                    label: Text(plan),
                    selected: data.planCode == plan,
                    onSelected: _busy || data.planCode == plan
                        ? null
                        : (_) => _run(
                            (repo) => repo.setPlan(widget.restaurantId, plan),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            _Heading(t.limitsLabel),
            for (final entry in data.limits.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(entry.key),
                trailing: Text(
                  entry.value?.toString() ?? t.unlimited,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(height: 22),
            _Heading(t.featuresLabel),
            Text(
              t.overriddenNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final feature in data.features)
              _FeatureRow(
                feature: feature,
                busy: _busy,
                onChange: (value) => _run((repo) {
                  if (value == null) {
                    return repo.clearFeature(widget.restaurantId, feature.key);
                  }
                  return repo.setFeature(
                    widget.restaurantId,
                    feature.key,
                    enabled: value,
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.feature,
    required this.busy,
    required this.onChange,
  });

  final VenueFeature feature;
  final bool busy;

  /// null puts the flag back under the plan.
  final ValueChanged<bool?> onChange;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.key,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  feature.inPlan ? t.byPlan : '—',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: feature.override != null
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0, label: Text(t.byPlan)),
              ButtonSegment(value: 1, label: Text(t.forcedOn)),
              ButtonSegment(value: 2, label: Text(t.forcedOff)),
            ],
            selected: {
              feature.override == null
                  ? 0
                  : feature.override!
                  ? 1
                  : 2,
            },
            onSelectionChanged: busy
                ? null
                : (picked) {
                    switch (picked.first) {
                      case 0:
                        onChange(null);
                      case 1:
                        onChange(true);
                      case 2:
                        onChange(false);
                    }
                  },
          ),
        ],
      ),
    );
  }
}
