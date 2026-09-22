import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../data/admin_repository.dart';

Future<void> editPromos(BuildContext context, WidgetRef ref, int restaurantId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PromosSheet(restaurantId),
  );
}

class _PromosSheet extends ConsumerStatefulWidget {
  const _PromosSheet(this.restaurantId);

  final int restaurantId;

  @override
  ConsumerState<_PromosSheet> createState() => _PromosSheetState();
}

class _PromosSheetState extends ConsumerState<_PromosSheet> {
  List<Map<String, dynamic>> _rows = const [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final rows = await ref
          .read(adminRepositoryProvider)
          .promos(widget.restaurantId);
      if (mounted) {
        setState(() {
          _rows = rows;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  Future<void> _add() async {
    final t = context.l10n;
    final code = TextEditingController();
    final amount = TextEditingController(text: '10');
    var kind = 'percent';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(t.promo),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: t.promo),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: kind,
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('%')),
                  DropdownMenuItem(value: 'amount', child: Text('₸')),
                ],
                onChanged: (v) => setLocal(() => kind = v ?? 'percent'),
              ),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t.priceTenge),
              ),
            ],
          ),
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
      ),
    );
    final raw = code.text.trim();
    final parsed = double.tryParse(amount.text) ?? 0;
    code.dispose();
    amount.dispose();
    if (ok != true || !mounted) return;
    try {
      await ref.read(adminRepositoryProvider).createPromo(widget.restaurantId, {
        'code': raw,
        'kind': kind,
        'value': parsed,
        'min_subtotal': 0,
      });
      await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.promo,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            for (final p in _rows)
              SwitchListTile(
                title: Text(p['code'] as String? ?? ''),
                subtitle: Text(
                  p['kind'] == 'percent' ? '${p['value']}%' : '${p['value']} ₸',
                ),
                value: p['is_active'] == true,
                onChanged: (v) async {
                  await ref
                      .read(adminRepositoryProvider)
                      .setPromoActive(p['id'] as int, v);
                  await _reload();
                },
              ),
          TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: Text(t.add),
          ),
        ],
      ),
    );
  }
}
