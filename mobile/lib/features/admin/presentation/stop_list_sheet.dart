import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../../restaurants/domain/menu_item.dart';
import '../data/admin_repository.dart';

/// What is off sale right now, and one tap to bring it back.
///
/// Reachable from the kitchen board on purpose: the person who discovers the
/// salmon has run out is standing at the pass, not in the menu editor.
Future<void> showStopList(
  BuildContext context,
  WidgetRef ref,
  int restaurantId,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _StopListSheet(restaurantId: restaurantId),
);

class _StopListSheet extends ConsumerStatefulWidget {
  const _StopListSheet({required this.restaurantId});

  final int restaurantId;

  @override
  ConsumerState<_StopListSheet> createState() => _StopListSheetState();
}

class _StopListSheetState extends ConsumerState<_StopListSheet> {
  var _busy = false;

  Future<void> _restore(List<int> ids) async {
    if (ids.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .setAvailability(widget.restaurantId, ids, available: true);
      Haptics.success();
      ref.invalidate(stopListProvider(widget.restaurantId));
      ref.invalidate(adminRestaurantProvider(widget.restaurantId));
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
    final stopped = ref.watch(stopListProvider(widget.restaurantId));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: stopped.when(
            loading: () => const ListSkeleton(count: 3, rowHeight: 64),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Text(errorMessage(e)),
            ),
            data: (items) => _Body(
              items: items,
              busy: _busy,
              onRestore: _restore,
              title: t.stopList,
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.items,
    required this.busy,
    required this.onRestore,
    required this.title,
  });

  final List<MenuItem> items;
  final bool busy;
  final ValueChanged<List<int>> onRestore;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: EmptyState(
          icon: Icons.check_circle_outline,
          title: t.stopListEmpty,
          hint: t.stopListEmptyHint,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$title · ${items.length}',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => onRestore([for (final item in items) item.id]),
              child: Text(t.restoreAll),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = items[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                subtitle: Text('${item.category} · ${formatMoney(item.price)}'),
                trailing: TextButton(
                  onPressed: busy ? null : () => onRestore([item.id]),
                  child: Text(t.restoreDish),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
