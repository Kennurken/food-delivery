import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../data/couriers_repository.dart';

/// The couriers this venue employs.
///
/// Adding one takes an email, because the courier has to exist first: they
/// register in the app like anyone, and hiring them is what turns the account
/// into a courier one. Removing turns it back, so nobody keeps seeing orders
/// after they leave.
Future<void> editCouriers(
  BuildContext context,
  WidgetRef ref,
  int restaurantId,
) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CouriersSheet(restaurantId: restaurantId),
  );
}

class CouriersSheet extends ConsumerStatefulWidget {
  const CouriersSheet({super.key, required this.restaurantId});

  final int restaurantId;

  @override
  ConsumerState<CouriersSheet> createState() => _CouriersSheetState();
}

class _CouriersSheetState extends ConsumerState<CouriersSheet> {
  final _email = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
      Haptics.success();
      ref.invalidate(venueCouriersProvider(widget.restaurantId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    await _run(
      () => ref
          .read(couriersRepositoryProvider)
          .add(widget.restaurantId, email)
          .then((_) => _email.clear()),
    );
  }

  Future<void> _remove(VenueCourier c) async {
    final t = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(t.removeCourierAsk),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await _run(
      () => ref
          .read(couriersRepositoryProvider)
          .remove(widget.restaurantId, c.userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final rows = ref.watch(venueCouriersProvider(widget.restaurantId));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.couriers,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                t.courierMustRegister,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        hintText: t.courierEmailHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _busy ? null : _add,
                    child: Text(t.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              rows.when(
                loading: () => const SizedBox(
                  height: 160,
                  child: ListSkeleton(count: 2, rowHeight: 56),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(errorMessage(e)),
                ),
                data: (list) => list.isEmpty
                    ? SizedBox(
                        height: 160,
                        child: EmptyState(
                          icon: Icons.delivery_dining_outlined,
                          title: t.noCouriersYet,
                        ),
                      )
                    : Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              list[i].name.isEmpty
                                  ? list[i].email
                                  : list[i].name,
                            ),
                            subtitle: Text(list[i].email),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _busy ? null : () => _remove(list[i]),
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
}
