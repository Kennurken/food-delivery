import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'editor_controller.dart';
import 'object_painter.dart';
import 'plan_theme.dart';

class ObjectPalette extends StatelessWidget {
  const ObjectPalette({
    super.key,
    required this.editor,
    this.horizontal = false,
  });

  final FloorEditor editor;
  final bool horizontal;

  static const _tables = [
    LayoutKind.tableRound,
    LayoutKind.tableSquare,
    LayoutKind.tableRect,
    LayoutKind.tableLarge,
    LayoutKind.tableCustom,
  ];
  static const _furniture = [
    LayoutKind.chair,
    LayoutKind.sofa,
    LayoutKind.booth,
    LayoutKind.stool,
    LayoutKind.reception,
    LayoutKind.counter,
  ];
  static const _structure = [
    LayoutKind.wall,
    LayoutKind.door,
    LayoutKind.window,
    LayoutKind.column,
    LayoutKind.stairs,
    LayoutKind.elevator,
  ];
  static const _infra = [
    LayoutKind.bar,
    LayoutKind.kitchen,
    LayoutKind.toilet,
    LayoutKind.entrance,
    LayoutKind.exit,
  ];

  @override
  Widget build(BuildContext context) {
    final sections = <(String, List<LayoutKind>)>[
      ('Tables', _tables),
      ('Furniture', _furniture),
      ('Structure', _structure),
      ('Rooms', _infra),
    ];
    if (horizontal) {
      return ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final section in sections)
            for (final k in section.$2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                child: _Tile(
                  kind: k,
                  selected: editor.placing == k,
                  compact: true,
                  onTap: () =>
                      editor.setPlacing(editor.placing == k ? null : k),
                ),
              ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
            child: Text(
              section.$1.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: PlanTheme.mute,
              ),
            ),
          ),
          for (final k in section.$2)
            _Tile(
              kind: k,
              selected: editor.placing == k,
              onTap: () => editor.setPlacing(editor.placing == k ? null : k),
            ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
          child: Text(
            'ZONES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: PlanTheme.mute,
            ),
          ),
        ),
        for (final z in ZoneKind.values)
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _parse(z.tint),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            title: Text(z.label, style: const TextStyle(fontSize: 13)),
            onTap: () => editor.addZone(z),
          ),
      ],
    );
  }

  Color _parse(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.kind,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final LayoutKind kind;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final thumb = SizedBox(
      width: compact ? 22 : 28,
      height: compact ? 22 : 28,
      child: CustomPaint(
        painter: ObjectPainter(
          node: LayoutNode(
            id: 0,
            kind: kind,
            x: 0,
            y: 0,
            width: 28,
            height: 28,
          ),
          selected: false,
          preview: true,
          warn: false,
          thumb: true,
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 8, vertical: 1),
      child: Material(
        color: selected
            ? PlanTheme.select.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 8,
              vertical: compact ? 6 : 7,
            ),
            child: compact
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      thumb,
                      const SizedBox(width: 6),
                      Text(kind.label, style: const TextStyle(fontSize: 12)),
                    ],
                  )
                : Row(
                    children: [
                      thumb,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          kind.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
