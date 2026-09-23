import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../../cart/domain/schedule_slots.dart';
import '../data/reservation_repository.dart';
import '../domain/reservation.dart';
import '../../../core/widgets/anim_icon.dart';

class MyReservationsScreen extends ConsumerWidget {
  const MyReservationsScreen({super.key});

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    Reservation row,
  ) async {
    try {
      await ref.read(reservationRepositoryProvider).cancel(row.id);
      ref.invalidate(myReservationsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.l10n;
    final rows = ref.watch(myReservationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.reservations)),
      body: rows.when(
        loading: () => const ListSkeleton(rowHeight: 88),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              shape: AnimShape.bell,
              title: t.noReservations,
              hint: t.noReservationsHint,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final row = list[i];
              final table = row.tableName;
              return Card(
                child: ListTile(
                  title: Text(row.restaurantName),
                  subtitle: Text(
                    [
                      formatSlot(row.startsAt.toLocal()),
                      t.guestsCount(row.guests),
                      if (table != null && table.isNotEmpty) table,
                      reservationStatusLabel(t, row.status),
                    ].join(' · '),
                  ),
                  trailing: row.canCancel
                      ? TextButton(
                          onPressed: () => _cancel(context, ref, row),
                          child: Text(t.cancelReservation),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
