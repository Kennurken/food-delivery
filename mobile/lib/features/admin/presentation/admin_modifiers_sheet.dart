import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../restaurants/domain/menu_item.dart';
import '../data/admin_repository.dart';

Future<void> editModifiers(
  BuildContext context,
  WidgetRef ref,
  MenuItem item, {
  required VoidCallback onSaved,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ModifiersSheet(item),
  );
  if (ok == true) onSaved();
}

class _DraftOption {
  _DraftOption({this.name = '', this.priceDelta = 0, this.isDefault = false});

  String name;
  double priceDelta;
  bool isDefault;
}

class _DraftGroup {
  _DraftGroup({
    this.name = '',
    this.required = false,
    this.maxSelect = 1,
    List<_DraftOption>? options,
  }) : options = options ?? [_DraftOption(isDefault: true)];

  String name;
  bool required;
  int maxSelect;
  List<_DraftOption> options;
}

class _ModifiersSheet extends ConsumerStatefulWidget {
  const _ModifiersSheet(this.item);

  final MenuItem item;

  @override
  ConsumerState<_ModifiersSheet> createState() => _ModifiersSheetState();
}

class _ModifiersSheetState extends ConsumerState<_ModifiersSheet> {
  late List<_DraftGroup> _groups;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _groups = [
      for (final g in widget.item.groups)
        _DraftGroup(
          name: g.name,
          required: g.required,
          maxSelect: g.maxSelect,
          options: [
            for (final o in g.options)
              _DraftOption(
                name: o.name,
                priceDelta: o.priceDelta,
                isDefault: o.isDefault,
              ),
          ],
        ),
    ];
  }

  Future<void> _save() async {
    final payload = [
      for (final g in _groups)
        if (g.name.trim().isNotEmpty &&
            g.options.any((o) => o.name.trim().isNotEmpty))
          {
            'name': g.name.trim(),
            'required': g.required,
            'min_select': g.required ? 1 : 0,
            'max_select': g.maxSelect < 1 ? 1 : g.maxSelect,
            'options': [
              for (final o in g.options)
                if (o.name.trim().isNotEmpty)
                  {
                    'name': o.name.trim(),
                    'price_delta': o.priceDelta,
                    'is_default': o.isDefault,
                  },
            ],
          },
    ];
    setState(() => _saving = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .replaceModifiers(widget.item.id, payload);
      if (mounted) Navigator.pop(context, true);
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
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + bottom + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${t.modifiers} · ${widget.item.name}',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (var gi = 0; gi < _groups.length; gi++)
              _GroupCard(
                group: _groups[gi],
                onChanged: () => setState(() {}),
                onRemove: () => setState(() => _groups.removeAt(gi)),
              ),
            TextButton.icon(
              onPressed: () => setState(() => _groups.add(_DraftGroup())),
              icon: const Icon(Icons.add),
              label: Text(t.addGroup),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.save),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.onChanged,
    required this.onRemove,
  });

  final _DraftGroup group;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: group.name,
                    decoration: InputDecoration(labelText: t.name),
                    onChanged: (v) => group.name = v,
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.required),
              value: group.required,
              onChanged: (v) {
                group.required = v;
                onChanged();
              },
            ),
            for (var oi = 0; oi < group.options.length; oi++)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: group.options[oi].name,
                      decoration: InputDecoration(labelText: t.optionName),
                      onChanged: (v) => group.options[oi].name = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 88,
                    child: TextFormField(
                      initialValue: group.options[oi].priceDelta
                          .round()
                          .toString(),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: t.priceDelta),
                      onChanged: (v) => group.options[oi].priceDelta =
                          double.tryParse(v) ?? 0,
                    ),
                  ),
                  Checkbox(
                    value: group.options[oi].isDefault,
                    onChanged: (v) {
                      group.options[oi].isDefault = v ?? false;
                      onChanged();
                    },
                  ),
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  group.options.add(_DraftOption());
                  onChanged();
                },
                child: Text(t.addOption),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
