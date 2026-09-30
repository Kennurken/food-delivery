import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../data/admin_repository.dart';
import '../data/menu_import_repository.dart';

/// Paste rows from Excel or Google Sheets, see what the server understood,
/// then load it. Two steps on purpose: a wrong column order should show up as
/// a preview full of odd prices, not as a hundred broken dishes.
Future<void> importMenu(BuildContext context, WidgetRef ref, int restaurantId) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => MenuImportSheet(restaurantId: restaurantId),
  );
}

class MenuImportSheet extends ConsumerStatefulWidget {
  const MenuImportSheet({super.key, required this.restaurantId});

  final int restaurantId;

  @override
  ConsumerState<MenuImportSheet> createState() => _MenuImportSheetState();
}

class _MenuImportSheetState extends ConsumerState<MenuImportSheet> {
  final _text = TextEditingController();
  ImportResult? _preview;
  var _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run({required bool dryRun}) async {
    if (_busy || _text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final t = context.l10n;
    try {
      final result = await ref
          .read(menuImportRepositoryProvider)
          .run(widget.restaurantId, _text.text, dryRun: dryRun);
      if (!mounted) return;
      if (dryRun) {
        setState(() => _preview = result);
        return;
      }
      Haptics.success();
      ref.invalidate(adminRestaurantProvider(widget.restaurantId));
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(t.menuImportDone(result.created, result.updated)),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _why(String? code) {
    final t = context.l10n;
    return switch (code) {
      'no_name' => t.menuImportNoName,
      'bad_price' => t.menuImportBadPrice,
      'name_too_long' => t.menuImportNameTooLong,
      'too_many_rows' => t.menuImportTooMany,
      _ => t.menuImportBadPrice,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final preview = _preview;
    final good = preview == null ? 0 : preview.created + preview.updated;
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
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.menuImport,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(t.menuImportHint, style: text.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                minLines: 4,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: t.menuImportExample,
                  border: const OutlineInputBorder(),
                ),
                // Any edit makes the old preview a lie about the new text.
                onChanged: (_) {
                  if (_preview != null) setState(() => _preview = null);
                },
              ),
              const SizedBox(height: 12),
              if (preview != null) ...[
                Text(
                  t.menuImportSummary(
                    preview.created,
                    preview.updated,
                    preview.errors,
                  ),
                  style: text.labelLarge,
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: preview.rows.length,
                    itemBuilder: (_, i) {
                      final row = preview.rows[i];
                      final bad = row.error != null;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          bad
                              ? Icons.error_outline
                              : row.action == 'update'
                              ? Icons.edit_outlined
                              : Icons.add_circle_outline,
                          color: bad ? scheme.error : scheme.primary,
                        ),
                        title: Text(
                          row.name.isEmpty ? '—' : row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          bad
                              ? t.menuImportLine(row.line, _why(row.error))
                              : row.category,
                        ),
                        trailing: row.price == null
                            ? null
                            : Text(formatMoney(row.price!)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (preview == null)
                FilledButton(
                  onPressed: _busy ? null : () => _run(dryRun: true),
                  child: Text(t.menuImportCheck),
                )
              else
                FilledButton(
                  onPressed: _busy || good == 0
                      ? null
                      : () => _run(dryRun: false),
                  child: Text(t.menuImportApply(good)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
