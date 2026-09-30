import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/haptics.dart';
import '../../restaurants/domain/opening_hours.dart';
import '../data/hours_repository.dart';

/// Bottom sheet to edit a venue's weekly opening hours.
Future<void> editHours(BuildContext context, WidgetRef ref, int restaurantId) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HoursSheet(restaurantId),
  );
}

class _HoursSheet extends ConsumerStatefulWidget {
  const _HoursSheet(this.restaurantId);

  final int restaurantId;

  @override
  ConsumerState<_HoursSheet> createState() => _HoursSheetState();
}

class _HoursSheetState extends ConsumerState<_HoursSheet> {
  List<OpeningStretch> _week = const [];
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final week = await ref
          .read(hoursRepositoryProvider)
          .week(widget.restaurantId);
      if (mounted) setState(() => _week = week);
    } catch (e) {
      _complain(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _complain(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(errorMessage(e))));
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(hoursRepositoryProvider).save(widget.restaurantId, _week);
      Haptics.success();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _complain(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addStretch(int weekday) {
    setState(() {
      _week = [
        ..._week,
        OpeningStretch(weekday: weekday, opens: '10:00', closes: '22:00'),
      ];
    });
  }

  void _removeStretch(int weekday, int index) {
    setState(() {
      final stretches = [..._week.where((s) => s.weekday == weekday)];
      if (index < stretches.length) {
        stretches.removeAt(index);
      }
      _week = [..._week.where((s) => s.weekday != weekday), ...stretches];
    });
  }

  Future<void> _pickTime(int weekday, int index, bool isOpen) async {
    final initial = isOpen
        ? _parseTime(
            _week.where((s) => s.weekday == weekday).elementAt(index).opens,
          )
        : _parseTime(
            _week.where((s) => s.weekday == weekday).elementAt(index).closes,
          );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    final timeStr =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';

    setState(() {
      final stretches = [..._week.where((s) => s.weekday == weekday)];
      if (index < stretches.length) {
        final s = stretches[index];
        stretches[index] = OpeningStretch(
          weekday: weekday,
          opens: isOpen ? timeStr : s.opens,
          closes: isOpen ? s.closes : timeStr,
        );
      }
      _week = [..._week.where((s) => s.weekday != weekday), ...stretches];
    });
  }

  TimeOfDay? _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  List<OpeningStretch> _stretchesForDay(int weekday) {
    return _week.where((s) => s.weekday == weekday).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final baseMonday = DateTime(2024, 1, 1);
    final localeName = Localizations.localeOf(context).toLanguageTag();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.openingHours,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (_loading)
                const _HoursSkeleton()
              else ...[
                // No stretches at all is a real state — "open whenever the
                // switch is on" — and the list below is still how you leave it.
                if (_week.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      t.noScheduleHint,
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: 7,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, day) {
                      final stretches = _stretchesForDay(day);
                      final dayName = DateFormat.EEEE(localeName)
                          .format(baseMonday.add(Duration(days: day)));

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dayName,
                              style: text.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (stretches.isEmpty)
                              Text(
                                t.dayOff,
                                style: text.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (var i = 0; i < stretches.length; i++)
                                    _StretchChip(
                                      stretch: stretches[i],
                                      index: i,
                                      onTapOpen: () => _pickTime(day, i, true),
                                      onTapClose: () =>
                                          _pickTime(day, i, false),
                                      onRemove: () => _removeStretch(day, i),
                                    ),
                                  _AddStretchButton(
                                    onTap: () => _addStretch(day),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(t.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StretchChip extends StatelessWidget {
  const _StretchChip({
    required this.stretch,
    required this.index,
    required this.onTapOpen,
    required this.onTapClose,
    required this.onRemove,
  });

  final OpeningStretch stretch;
  final int index;
  final VoidCallback onTapOpen;
  final VoidCallback onTapClose;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    final isRoundTheClock = stretch.opens == stretch.closes;
    final label = isRoundTheClock
        ? t.roundTheClock
        : '${stretch.opens}–${stretch.closes}';

    return GestureDetector(
      onLongPress: onTapClose,
      child: InputChip(
        label: Text(label),
        onPressed: onTapOpen,
        onDeleted: onRemove,
        deleteIcon: const Icon(Icons.close, size: 18),
        avatar: Icon(Icons.schedule, size: 18, color: scheme.primary),
      ),
    );
  }
}

class _AddStretchButton extends StatelessWidget {
  const _AddStretchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return ActionChip(
      avatar: Icon(Icons.add, size: 18, color: scheme.primary),
      label: Text(t.addStretch),
      onPressed: onTap,
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.5),
    );
  }
}

class _HoursSkeleton extends StatelessWidget {
  const _HoursSkeleton();

  @override
  // Four placeholder days, not seven: seven overflow a small phone's sheet
  // for the moment it takes to load, and nobody counts them.
  Widget build(BuildContext context) => Column(
    children: List.generate(
      4,
      (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 16,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                2,
                (j) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 80,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
