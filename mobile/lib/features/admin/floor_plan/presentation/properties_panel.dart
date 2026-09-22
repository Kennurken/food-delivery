import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/geometry.dart';
import '../domain/models.dart';
import 'editor_controller.dart';
import 'plan_theme.dart';

class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key, required this.editor});

  final FloorEditor editor;

  @override
  Widget build(BuildContext context) {
    final zone = editor.primaryZone;
    final n = editor.primary;
    if (n == null && zone == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          editor.placing != null
              ? 'Click the floor to place ${editor.placing!.label.toLowerCase()}.'
              : 'Select an object to edit its properties.',
          style: const TextStyle(color: PlanTheme.mute, height: 1.4),
        ),
      );
    }
    if (zone != null && n == null) {
      return _ZoneProps(editor: editor);
    }
    return _ObjectProps(editor: editor);
  }
}

class _ZoneProps extends StatelessWidget {
  const _ZoneProps({required this.editor});
  final FloorEditor editor;

  @override
  Widget build(BuildContext context) {
    final z = editor.primaryZone!;
    return KeyedSubtree(
      key: ValueKey('zone-${z.id}'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          Text(
            z.name.toUpperCase(),
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
          ),
          const SizedBox(height: 14),
          _field(
            context,
            'Name',
            z.name,
            id: z.id,
            on: (v) => editor.patchZone((o) => o.name = v),
          ),
          const SizedBox(height: 10),
          Text('Type', style: _lab(context)),
          const SizedBox(height: 4),
          DropdownButtonFormField<ZoneKind>(
            key: ValueKey('zk-${z.id}'),
            initialValue: z.kind,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final k in ZoneKind.values)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (k) {
              if (k == null) return;
              editor.patchZone((o) {
                o.kind = k;
                o.color = k.tint;
              });
            },
          ),
          const SizedBox(height: 10),
          _intField(
            context,
            'Capacity',
            z.capacity ?? 0,
            on: (v) => editor.patchZone((o) => o.capacity = v),
          ),
          const SizedBox(height: 10),
          _field(
            context,
            'Description',
            z.description,
            on: (v) => editor.patchZone((o) => o.description = v),
            id: 'd-${z.id}',
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: editor.deleteSelected,
            child: const Text('Delete zone'),
          ),
        ],
      ),
    );
  }
}

class _ObjectProps extends StatelessWidget {
  const _ObjectProps({required this.editor});
  final FloorEditor editor;

  @override
  Widget build(BuildContext context) {
    final n = editor.primary!;
    final d = editor.doc;
    return KeyedSubtree(
      key: ValueKey('obj-${n.id}'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          Text(
            (n.name.isEmpty ? n.kind.label : n.name).toUpperCase(),
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.4),
          ),
          const SizedBox(height: 4),
          Text(
            n.kind.label,
            style: const TextStyle(color: PlanTheme.mute, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _field(
            context,
            'Name',
            n.name,
            id: n.id,
            on: (v) => editor.patchPrimary((o) => o.name = v),
          ),
          if (n.kind.isTable) ...[
            const SizedBox(height: 10),
            Text('Type', style: _lab(context)),
            const SizedBox(height: 4),
            DropdownButtonFormField<LayoutKind>(
              key: ValueKey('tk-${n.id}'),
              initialValue: n.kind,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                for (final k in LayoutKind.values.where((k) => k.isTable))
                  DropdownMenuItem(value: k, child: Text(k.label)),
              ],
              onChanged: (k) {
                if (k != null) editor.patchPrimary((o) => o.kind = k);
              },
            ),
            const SizedBox(height: 10),
            _intField(
              context,
              'Capacity',
              n.capacity ?? 0,
              on: (v) => editor.patchPrimary((o) => o.capacity = v),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _intField(
                    context,
                    'Min guests',
                    n.minGuests ?? 1,
                    on: (v) => editor.patchPrimary((o) => o.minGuests = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _intField(
                    context,
                    'Max guests',
                    n.maxGuests ?? n.capacity ?? 4,
                    on: (v) => editor.patchPrimary((o) => o.maxGuests = v),
                  ),
                ),
              ],
            ),
            if (d != null && d.zones.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Zone', style: _lab(context)),
              const SizedBox(height: 4),
              DropdownButtonFormField<int?>(
                key: ValueKey('zn-${n.id}-${n.zoneId}'),
                initialValue: n.zoneId,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  for (final z in d.zones)
                    DropdownMenuItem(value: z.id, child: Text(z.name)),
                ],
                onChanged: (id) => editor.patchPrimary((o) => o.zoneId = id),
              ),
            ],
            const SizedBox(height: 12),
            Text('Status', style: _lab(context)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in TableStatus.values)
                  ChoiceChip(
                    avatar: Icon(
                      Icons.circle,
                      size: 10,
                      color: _statusColor(s),
                    ),
                    label: Text(s.label),
                    selected: n.status == s,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => editor.patchPrimary((o) => o.status = s),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text('Position (cm)', style: _lab(context)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _numField(
                  context,
                  'X',
                  n.x,
                  on: (v) => editor.patchPrimary((o) => o.x = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _numField(
                  context,
                  'Y',
                  n.y,
                  on: (v) => editor.patchPrimary((o) => o.y = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _numField(
                  context,
                  'W',
                  n.width,
                  on: (v) => editor.resize(n.id, v, n.height),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _numField(
                  context,
                  'H',
                  n.height,
                  on: (v) => editor.resize(n.id, n.width, v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _numField(
            context,
            'Rotation',
            n.rotation,
            on: (v) => editor.rotate(n.id, v),
          ),
          if (n.kind.isTable) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mergeable'),
              value: n.mergeable,
              onChanged: (v) => editor.patchPrimary((o) => o.mergeable = v),
            ),
          ],
          if (editor.selected.length > 1) ...[
            const SizedBox(height: 8),
            Text('Align', style: _lab(context)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _mini('Left', () => editor.applyAlign(alignLeft)),
                _mini('Center', () => editor.applyAlign(alignCenter)),
                _mini('Right', () => editor.applyAlign(alignRight)),
                _mini('Top', () => editor.applyAlign(alignTop)),
                _mini('Middle', () => editor.applyAlign(alignMiddle)),
                _mini('Bottom', () => editor.applyAlign(alignBottom)),
                _mini('Dist H', () => editor.applyAlign(distributeH)),
                _mini('Dist V', () => editor.applyAlign(distributeV)),
                _mini('Combine', editor.mergeSelected),
                _mini('Uncombine', editor.unmergeSelected),
                _mini('Group', editor.groupSelected),
                _mini('Ungroup', editor.ungroupSelected),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: editor.duplicateSelected,
                  child: const Text('Duplicate'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: editor.deleteSelected,
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
          if (editor.warnings.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Warnings', style: _lab(context)),
            const SizedBox(height: 6),
            for (final w in editor.warnings.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '⚠ ${_warn(w)}',
                  style: const TextStyle(
                    color: PlanTheme.warn,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _warn(LayoutWarning w) {
    final who = '#${w.objectId}';
    return switch (w.kind) {
      LayoutWarningKind.overlap => 'Object $who overlaps another object',
      LayoutWarningKind.outside => 'Object $who is outside the floor boundary',
      LayoutWarningKind.doorBlocked => 'Door opening area is blocked',
      LayoutWarningKind.clearance => 'Insufficient clearance around table $who',
    };
  }

  Color _statusColor(TableStatus s) => switch (s) {
    TableStatus.available => const Color(0xFF2F6B3A),
    TableStatus.reserved => const Color(0xFFB8860B),
    TableStatus.occupied => const Color(0xFFB42318),
    TableStatus.cleaning => const Color(0xFF1D4E89),
    TableStatus.disabled => const Color(0xFF5C564E),
  };
}

TextStyle? _lab(BuildContext context) =>
    Theme.of(context).textTheme.labelSmall
        ?.copyWith(fontWeight: FontWeight.w700, color: PlanTheme.mute);

Widget _mini(String l, VoidCallback on) => ActionChip(
  label: Text(l),
  visualDensity: VisualDensity.compact,
  onPressed: on,
);

Widget _field(
  BuildContext context,
  String label,
  String value, {
  Object? id,
  required ValueChanged<String> on,
}) {
  return TextFormField(
    key: ValueKey('n-$label-$id'),
    initialValue: value,
    decoration: InputDecoration(labelText: label, isDense: true),
    onChanged: on,
  );
}

Widget _numField(
  BuildContext context,
  String label,
  double value, {
  Object? id,
  required ValueChanged<double> on,
}) {
  return TextFormField(
    key: ValueKey('d-$label-$id'),
    initialValue: value.toStringAsFixed(0),
    decoration: InputDecoration(labelText: label, isDense: true),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))],
    onFieldSubmitted: (v) {
      final n = double.tryParse(v);
      if (n != null) on(n);
    },
  );
}

Widget _intField(
  BuildContext context,
  String label,
  int value, {
  Object? id,
  required ValueChanged<int> on,
}) {
  return TextFormField(
    key: ValueKey('i-$label-$id'),
    initialValue: '$value',
    decoration: InputDecoration(labelText: label, isDense: true),
    keyboardType: TextInputType.number,
    onChanged: (v) {
      final n = int.tryParse(v);
      if (n != null) on(n);
    },
  );
}
