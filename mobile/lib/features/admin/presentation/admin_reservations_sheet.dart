import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/domain/schedule_slots.dart';
import '../data/admin_repository.dart';

Future<void> editReservations(
  BuildContext context,
  WidgetRef ref,
  int restaurantId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReservationsSheet(restaurantId),
  );
}

class _ReservationsSheet extends ConsumerStatefulWidget {
  const _ReservationsSheet(this.restaurantId);

  final int restaurantId;

  @override
  ConsumerState<_ReservationsSheet> createState() => _ReservationsSheetState();
}

class _ReservationsSheetState extends ConsumerState<_ReservationsSheet> {
  List<Map<String, dynamic>> _rows = const [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final rows = await ref
          .read(adminRepositoryProvider)
          .reservations(widget.restaurantId);
      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  Future<void> _set(int id, String status) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateReservation(id, status: status);
      await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  Future<void> _walkIn() async {
    final t = context.l10n;
    final user = ref.read(authControllerProvider).value;
    final name = TextEditingController(text: user?.name ?? '');
    final guests = TextEditingController(text: '2');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.walkIn),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: t.name),
            ),
            TextField(
              controller: guests,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: t.guests),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.save),
          ),
        ],
      ),
    );
    final guestName = name.text.trim();
    final n = int.tryParse(guests.text) ?? 2;
    name.dispose();
    guests.dispose();
    if (ok != true || !mounted || guestName.isEmpty) return;
    try {
      await ref.read(adminRepositoryProvider).createReservation(
        widget.restaurantId,
        {
          'restaurant_id': widget.restaurantId,
          'name': guestName,
          'guests': n.clamp(1, 20),
          'starts_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.7;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.reservations,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: ListView(
                  children: [
                    for (final row in _rows)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(row['name'] as String? ?? ''),
                        subtitle: Text(
                          [
                            formatSlot(
                              DateTime.parse(row['starts_at'] as String)
                                  .toLocal(),
                            ),
                            t.guestsCount(row['guests'] as int? ?? 2),
                            if ((row['table_name'] as String?)?.isNotEmpty ==
                                true)
                              row['table_name'] as String,
                            reservationStatusLabel(
                              t,
                              row['status'] as String? ?? '',
                            ),
                          ].join(' · '),
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            if (row['status'] == 'requested')
                              TextButton(
                                onPressed: () =>
                                    _set(row['id'] as int, 'confirmed'),
                                child: Text(t.confirmReservation),
                              ),
                            if (row['status'] == 'confirmed')
                              TextButton(
                                onPressed: () =>
                                    _set(row['id'] as int, 'seated'),
                                child: Text(t.seatGuest),
                              ),
                            if (row['status'] == 'requested' ||
                                row['status'] == 'confirmed')
                              TextButton(
                                onPressed: () =>
                                    _set(row['id'] as int, 'cancelled'),
                                child: Text(t.cancel),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: _walkIn,
              icon: const Icon(Icons.add),
              label: Text(t.walkIn),
            ),
          ],
        ),
      ),
    );
  }
}
