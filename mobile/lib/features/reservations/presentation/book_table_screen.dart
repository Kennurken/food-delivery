import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/buttons.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/pressable.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../cart/domain/schedule_slots.dart';
import '../../restaurants/data/restaurant_repository.dart';
import '../data/reservation_repository.dart';
import '../domain/floor_table.dart';

class BookTableScreen extends ConsumerStatefulWidget {
  const BookTableScreen({super.key, required this.restaurantId});

  final int restaurantId;

  @override
  ConsumerState<BookTableScreen> createState() => _BookTableScreenState();
}

class _BookTableScreenState extends ConsumerState<BookTableScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _note;
  var _guests = 2;
  DateTime? _when;
  int? _tableId;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).value;
    _name = TextEditingController(text: user?.name ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _note = TextEditingController();
    final slots = reservationSlots(DateTime.now());
    _when = slots.isEmpty ? null : slots.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final slots = reservationSlots(DateTime.now());
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            for (final slot in slots)
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(formatSlot(slot)),
                onTap: () => Navigator.pop(ctx, slot),
              ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _when = picked);
  }

  Future<void> _submit() async {
    final t = context.l10n;
    final when = _when;
    final name = _name.text.trim();
    if (when == null || name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(reservationRepositoryProvider)
          .create(
            restaurantId: widget.restaurantId,
            name: name,
            phone: _phone.text.trim(),
            guests: _guests,
            startsAt: when,
            tableObjectId: _tableId,
            comment: _note.text.trim(),
          );
      Haptics.success();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.booked)));
      context.go('/reservations');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final restaurant = ref.watch(restaurantProvider(widget.restaurantId));
    final tables = ref.watch(restaurantTablesProvider(widget.restaurantId));
    return Scaffold(
      appBar: AppBar(title: Text(t.bookTable)),
      body: restaurant.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (r) {
          if (!r.allowsReservations) {
            return Center(child: Text(t.noReservations));
          }
          final rows = tables.value ?? const <FloorTable>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              Text(
                r.name,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: t.name,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: t.phone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t.guests,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _guests <= 1
                        ? null
                        : () => setState(() => _guests--),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$_guests',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    onPressed: _guests >= 20
                        ? null
                        : () => setState(() => _guests++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(_when == null ? t.schedule : formatSlot(_when!)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickTime,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                t.pickTable,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(t.anyTable),
                    selected: _tableId == null,
                    onSelected: (_) => setState(() => _tableId = null),
                  ),
                  for (final table in rows)
                    ChoiceChip(
                      label: Text(
                        table.capacity == null
                            ? table.name
                            : '${table.name} · ${t.tableSeats(table.capacity!)}',
                      ),
                      selected: _tableId == table.id,
                      onSelected: (_) => setState(() => _tableId = table.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: t.orderNote,
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Pressable(
            onTap: _saving ? null : _submit,
            child: FilledButton(
              style: AppButtons.inline,
              onPressed: _saving ? null : _submit,
              child: Text(t.book),
            ),
          ),
        ),
      ),
    );
  }
}
