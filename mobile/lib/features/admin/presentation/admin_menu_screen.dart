import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/stagger.dart';
import '../../../core/widgets/stretch_switch.dart';
import '../../restaurants/domain/menu_item.dart';
import '../data/admin_repository.dart';

class AdminMenuScreen extends ConsumerWidget {
  const AdminMenuScreen({super.key, required this.restaurantId});

  final int restaurantId;

  void _refresh(WidgetRef ref) {
    ref.invalidate(adminRestaurantProvider(restaurantId));
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() op,
  ) async {
    try {
      await op();
      _refresh(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    MenuItem? item,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MenuItemDialog(item: item),
    );
    if (result == null || !context.mounted) return;
    final repo = ref.read(adminRepositoryProvider);
    await _run(
      context,
      ref,
      () => item == null
          ? repo.createMenuItem(restaurantId, result)
          : repo.updateMenuItem(item.id, result),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = ref.watch(adminRestaurantProvider(restaurantId));
    return Scaffold(
      appBar: AppBar(
        title: Text(restaurant.value?.name ?? context.l10n.menu),
        actions: [
          TextButton.icon(
            onPressed: () =>
                context.push('/admin/restaurants/$restaurantId/floor'),
            icon: const Icon(Icons.grid_on, size: 18),
            label: Text(context.l10n.floorPlan),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, ref),
        child: const Icon(Icons.add),
      ),
      body: restaurant.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(errorMessage(e))),
        data: (r) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: r.menu.length,
          itemBuilder: (_, i) {
            final m = r.menu[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  title: Text(m.name),
                  subtitle: Text('${m.category} · ${formatMoney(m.price)}'),
                  onTap: () => _edit(context, ref, item: m),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StretchSwitch(
                        value: m.isAvailable,
                        onChanged: (v) => _run(
                          context,
                          ref,
                          () => ref
                              .read(adminRepositoryProvider)
                              .updateMenuItem(m.id, {'is_available': v}),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final t = context.l10n;
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(t.deleteItemTitle(m.name)),
                              content: Text(t.deleteItemBody),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(t.cancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(t.delete),
                                ),
                              ],
                            ),
                          );
                          if (ok == true && context.mounted) {
                            await _run(
                              context,
                              ref,
                              () => ref
                                  .read(adminRepositoryProvider)
                                  .deleteMenuItem(m.id),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ).stagger(i);
          },
        ),
      ),
    );
  }
}

class _MenuItemDialog extends StatefulWidget {
  const _MenuItemDialog({this.item});

  final MenuItem? item;

  @override
  State<_MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends State<_MenuItemDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _desc = TextEditingController(text: widget.item?.description);
  late final _price = TextEditingController(
    text: widget.item?.price.round().toString(),
  );
  late final _category = TextEditingController(
    text: widget.item?.category ?? 'Main',
  );

  @override
  void dispose() {
    for (final c in [_name, _desc, _price, _category]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.item == null ? context.l10n.newItem : context.l10n.editItem,
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: context.l10n.name),
              validator: (v) => v != null && v.trim().isNotEmpty
                  ? null
                  : context.l10n.required,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _desc,
              decoration: InputDecoration(labelText: context.l10n.description),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.l10n.priceTenge),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0
                  ? null
                  : context.l10n.mustBePositive,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _category,
              decoration: InputDecoration(labelText: context.l10n.category),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context, {
              'name': _name.text.trim(),
              'description': _desc.text.trim(),
              'price': double.parse(_price.text),
              'category': _category.text.trim().isEmpty
                  ? 'Main'
                  : _category.text.trim(),
            });
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}
