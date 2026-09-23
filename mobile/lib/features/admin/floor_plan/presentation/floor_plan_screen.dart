import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/widgets/empty_state.dart';
import '../domain/models.dart';
import 'editor_controller.dart';
import 'floor_canvas.dart';
import 'object_palette.dart';
import 'plan_theme.dart';
import 'properties_panel.dart';
import '../../../../core/widgets/anim_icon.dart';

class FloorPlanScreen extends ConsumerWidget {
  const FloorPlanScreen({super.key, required this.restaurantId});

  final int restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(floorEditorProvider(restaurantId));
    return ListenableBuilder(
      listenable: editor,
      builder: (context, _) =>
          _EditorScaffold(restaurantId: restaurantId, editor: editor),
    );
  }
}

class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({required this.restaurantId, required this.editor});

  final int restaurantId;
  final FloorEditor editor;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 960;
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !editor.dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave(context, editor);
        if (leave == true && context.mounted) {
          editor.dirty = false;
          context.pop();
        }
      },
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _UndoIntent(),
          SingleActivator(LogicalKeyboardKey.keyZ, control: true):
              _UndoIntent(),
          SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
              _RedoIntent(),
          SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
              _RedoIntent(),
          SingleActivator(LogicalKeyboardKey.keyD, meta: true): _DupIntent(),
          SingleActivator(LogicalKeyboardKey.keyD, control: true): _DupIntent(),
          SingleActivator(LogicalKeyboardKey.keyC, meta: true): _CopyIntent(),
          SingleActivator(LogicalKeyboardKey.keyC, control: true):
              _CopyIntent(),
          SingleActivator(LogicalKeyboardKey.keyV, meta: true): _PasteIntent(),
          SingleActivator(LogicalKeyboardKey.keyV, control: true):
              _PasteIntent(),
          SingleActivator(LogicalKeyboardKey.delete): _DelIntent(),
          SingleActivator(LogicalKeyboardKey.backspace): _DelIntent(),
          SingleActivator(LogicalKeyboardKey.escape): _EscIntent(),
          SingleActivator(LogicalKeyboardKey.keyS, meta: true): _SaveIntent(),
          SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _SaveIntent(),
        },
        child: Actions(
          actions: {
            _UndoIntent: CallbackAction<_UndoIntent>(
              onInvoke: (_) {
                editor.undo();
                return null;
              },
            ),
            _RedoIntent: CallbackAction<_RedoIntent>(
              onInvoke: (_) {
                editor.redo();
                return null;
              },
            ),
            _DupIntent: CallbackAction<_DupIntent>(
              onInvoke: (_) {
                editor.duplicateSelected();
                return null;
              },
            ),
            _CopyIntent: CallbackAction<_CopyIntent>(
              onInvoke: (_) {
                editor.copySelected();
                return null;
              },
            ),
            _PasteIntent: CallbackAction<_PasteIntent>(
              onInvoke: (_) {
                editor.paste();
                return null;
              },
            ),
            _DelIntent: CallbackAction<_DelIntent>(
              onInvoke: (_) {
                editor.deleteSelected();
                return null;
              },
            ),
            _EscIntent: CallbackAction<_EscIntent>(
              onInvoke: (_) {
                editor.deselect();
                return null;
              },
            ),
            _SaveIntent: CallbackAction<_SaveIntent>(
              onInvoke: (_) {
                editor.persist();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Theme(
              data: Theme.of(context).copyWith(
                filledButtonTheme: FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  isDense: true,
                  filled: true,
                  fillColor: scheme.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: scheme.primary, width: 1.4),
                  ),
                ),
              ),
              child: Scaffold(
                backgroundColor: scheme.surface,
                body: Column(
                  children: [
                    _Toolbar(
                      editor: editor,
                      compact: compact,
                      onSave: () => _save(context, editor),
                      onHistory: () => _history(context, editor),
                      onNewFloor: () => _newFloor(context, editor),
                      onRename: () => _rename(context, editor),
                    ),
                    Expanded(child: _body(context, compact)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, bool compact) {
    if (editor.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (editor.error != null && editor.doc == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(editor.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: editor.load,
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }
    if (editor.doc == null) {
      return EmptyState(
        shape: AnimShape.grid,
        title: context.l10n.noFloorPlan,
        hint: context.l10n.noFloorPlanHint,
        action: FilledButton(
          onPressed: () => _newFloor(context, editor),
          child: Text(context.l10n.createFloorPlan),
        ),
      );
    }
    return Column(
      children: [
        if (!editor.preview) _StatusBar(editor: editor),
        Expanded(
          child: compact
              ? Column(
                  children: [
                    Expanded(child: FloorCanvas(editor: editor)),
                    if (!editor.preview) ...[
                      if (editor.primary != null || editor.primaryZone != null)
                        _MobilePropsBar(
                          editor: editor,
                          onOpen: () => _sheet(context, editor),
                        ),
                      SizedBox(
                        height: 72,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: PlanTheme.hairline(context),
                              ),
                            ),
                          ),
                          child: ObjectPalette(
                            editor: editor,
                            horizontal: true,
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              : Row(
                  children: [
                    if (!editor.preview)
                      SizedBox(
                        width: 228,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: PlanTheme.panel(context),
                            border: Border(
                              right: BorderSide(
                                color: PlanTheme.hairline(context),
                              ),
                            ),
                          ),
                          child: ObjectPalette(editor: editor),
                        ),
                      ),
                    Expanded(child: FloorCanvas(editor: editor)),
                    if (!editor.preview)
                      SizedBox(
                        width: 292,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: PlanTheme.panel(context),
                            border: Border(
                              left: BorderSide(
                                color: PlanTheme.hairline(context),
                              ),
                            ),
                          ),
                          child: PropertiesPanel(editor: editor),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, FloorEditor editor) async {
    await editor.persist();
    if (editor.save == SaveMark.failed && context.mounted) {
      _saveFailed(context, editor);
    }
  }

  Future<void> _newFloor(BuildContext context, FloorEditor editor) async {
    final t = context.l10n;
    final name = TextEditingController(text: t.firstFloor);
    final template = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.createFloorPlan),
        content: TextField(
          controller: name,
          decoration: InputDecoration(labelText: t.name),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(t.startScratch),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'cafe'),
            child: Text(t.useTemplate),
          ),
        ],
      ),
    );
    final label = name.text.trim().isEmpty ? t.firstFloor : name.text.trim();
    name.dispose();
    if (template == null) return;
    await editor.createFloor(
      name: label,
      template: template.isEmpty ? null : template,
    );
  }

  Future<void> _rename(BuildContext context, FloorEditor editor) async {
    final t = context.l10n;
    final name = TextEditingController(text: editor.doc?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.renameFloor),
        content: TextField(controller: name, autofocus: true),
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
    final next = name.text.trim();
    name.dispose();
    if (ok == true && next.isNotEmpty) {
      await editor.renameFloor(next);
    }
  }

  Future<void> _history(BuildContext context, FloorEditor editor) async {
    final t = context.l10n;
    await editor.refreshVersions();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        if (editor.versions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No saved versions yet. Save a layout to create one.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                t.history,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final v in editor.versions)
              ListTile(
                title: Text(v.$2),
                subtitle: Text(v.$3),
                trailing: TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await editor.restoreVersion(v.$1);
                  },
                  child: const Text('Restore'),
                ),
              ),
          ],
        );
      },
    );
  }

  void _saveFailed(BuildContext context, FloorEditor editor) {
    final t = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.layoutSaveFailed),
        content: Text(
          editor.conflict
              ? 'This floor was edited elsewhere. Keep your local copy or reload.'
              : t.layoutSaveFailedBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.continueEditing),
          ),
          if (editor.conflict)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                editor.reloadFromServer();
              },
              child: const Text('Reload'),
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              editor.persist();
            },
            child: Text(t.retry),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmLeave(BuildContext context, FloorEditor editor) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Leave without saving the floor plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () async {
              await editor.persist();
              if (ctx.mounted) {
                Navigator.pop(ctx, editor.save == SaveMark.saved);
              }
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
  }

  void _sheet(BuildContext context, FloorEditor editor) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: PropertiesPanel(editor: editor),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.editor,
    required this.compact,
    required this.onSave,
    required this.onHistory,
    required this.onNewFloor,
    required this.onRename,
  });

  final FloorEditor editor;
  final bool compact;
  final VoidCallback onSave;
  final VoidCallback onHistory;
  final VoidCallback onNewFloor;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: PlanTheme.hairline(context)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: () => context.pop(),
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                  ),
                  if (!compact) ...[
                    Text(
                      t.floorPlan,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (editor.floors.isNotEmpty)
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: editor.doc?.id,
                        isDense: true,
                        items: [
                          for (final f in editor.floors)
                            DropdownMenuItem(value: f.id, child: Text(f.name)),
                        ],
                        onChanged: (id) {
                          if (id != null) editor.openFloor(id);
                        },
                      ),
                    ),
                  PopupMenuButton<String>(
                    tooltip: t.addFloor,
                    padding: EdgeInsets.zero,
                    onSelected: (v) async {
                      switch (v) {
                        case 'add':
                          onNewFloor();
                        case 'rename':
                          onRename();
                        case 'dup':
                          await editor.duplicateFloor();
                        case 'delete':
                          await editor.deleteFloor();
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'add', child: Text(t.addFloor)),
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(t.renameFloor),
                      ),
                      PopupMenuItem(
                        value: 'dup',
                        child: Text(t.duplicateFloor),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(t.deleteFloor),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Undo',
                    onPressed: editor.canUndo ? editor.undo : null,
                    icon: const Icon(Icons.undo, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Redo',
                    onPressed: editor.canRedo ? editor.redo : null,
                    icon: const Icon(Icons.redo, size: 20),
                  ),
                  if (!compact)
                    TextButton(
                      onPressed: editor.togglePreview,
                      child: Text(
                        editor.preview ? t.editLayout : t.previewLayout,
                      ),
                    ),
                  if (!compact)
                    IconButton(
                      tooltip: t.history,
                      onPressed: onHistory,
                      icon: const Icon(Icons.history, size: 20),
                    ),
                  if (!compact)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        switch (editor.save) {
                          SaveMark.saved => t.layoutSaved,
                          SaveMark.saving => t.layoutSaving,
                          SaveMark.unsaved => t.layoutUnsaved,
                          SaveMark.failed => t.layoutSaveFailed,
                        },
                        style: TextStyle(
                          fontSize: 12,
                          color: editor.save == SaveMark.failed
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: editor.dirty && editor.save != SaveMark.saving
                        ? onSave
                        : null,
                    child: Text(t.save),
                  ),
                  if (compact)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        switch (v) {
                          case 'preview':
                            editor.togglePreview();
                          case 'history':
                            onHistory();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'preview',
                          child: Text(
                            editor.preview ? t.editLayout : t.previewLayout,
                          ),
                        ),
                        PopupMenuItem(value: 'history', child: Text(t.history)),
                      ],
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.editor});
  final FloorEditor editor;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final d = editor.doc;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: PlanTheme.panel(context),
        border: Border(bottom: BorderSide(color: PlanTheme.hairline(context))),
      ),
      child: Row(
        children: [
          if (d != null && d.zones.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: editor.selectedZone,
                hint: const Text('All zones'),
                isDense: true,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All zones'),
                  ),
                  for (final z in d.zones)
                    DropdownMenuItem(value: z.id, child: Text(z.name)),
                ],
                onChanged: editor.selectZone,
              ),
            ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(editor.snap ? t.snapOn : t.snapOff),
            selected: editor.snap,
            visualDensity: VisualDensity.compact,
            onSelected: (_) => editor.toggleSnap(),
          ),
          const SizedBox(width: 8),
          for (final g in [20, 40, 80])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text('${g}cm'),
                selected: editor.doc?.gridCm == g,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => editor.setGrid(g),
              ),
            ),
          const Spacer(),
          Text(
            '1 m = 100 units',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: PlanTheme.mute),
          ),
        ],
      ),
    );
  }
}

class _MobilePropsBar extends StatelessWidget {
  const _MobilePropsBar({required this.editor, required this.onOpen});
  final FloorEditor editor;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final n = editor.primary;
    final z = editor.primaryZone;
    final label = n?.name.isNotEmpty == true
        ? n!.name
        : (n?.kind.label ?? z?.name ?? '');
    return Material(
      color: PlanTheme.panel(context),
      child: ListTile(
        dense: true,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: n != null && n.kind.isTable
            ? Text('${n.capacity ?? 0} seats · ${n.status.label}')
            : null,
        trailing: TextButton(
          onPressed: onOpen,
          child: const Text('Properties'),
        ),
      ),
    );
  }
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _DupIntent extends Intent {
  const _DupIntent();
}

class _CopyIntent extends Intent {
  const _CopyIntent();
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

class _DelIntent extends Intent {
  const _DelIntent();
}

class _EscIntent extends Intent {
  const _EscIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}
