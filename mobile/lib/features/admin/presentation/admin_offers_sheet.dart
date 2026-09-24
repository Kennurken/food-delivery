import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/anim_icon.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/list_skeleton.dart';
import '../data/admin_repository.dart';

/// Campaigns for one venue.
///
/// The list shows hidden and finished ones too, unlike the site: the owner has
/// to be able to find the campaign they switched off in order to switch it back.
Future<void> editOffers(BuildContext context, WidgetRef ref, int restaurantId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _OffersSheet(restaurantId),
  );
}

class _OffersSheet extends ConsumerStatefulWidget {
  const _OffersSheet(this.restaurantId);

  final int restaurantId;

  @override
  ConsumerState<_OffersSheet> createState() => _OffersSheetState();
}

class _OffersSheetState extends ConsumerState<_OffersSheet> {
  List<Map<String, dynamic>> _rows = const [];
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final rows = await ref
          .read(adminRepositoryProvider)
          .offers(widget.restaurantId);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      _complain(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _complain(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(errorMessage(e))));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      Haptics.success();
      await _reload();
    } catch (e) {
      _complain(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit({Map<String, dynamic>? row}) async {
    final body = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OfferForm(row: row),
    );
    if (body == null) return;
    await _run(
      () async => row == null
          ? await ref
                .read(adminRepositoryProvider)
                .createOffer(widget.restaurantId, body)
          : await ref
                .read(adminRepositoryProvider)
                .updateOffer(row['id'] as int, body),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.campaigns,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => _edit(),
                    icon: const AnimIcon(AnimShape.plus),
                  ),
                ],
              ),
              if (_loading)
                const ListSkeleton(count: 3, rowHeight: 72)
              else if (_rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(
                    shape: AnimShape.tag,
                    title: t.noCampaigns,
                    hint: t.noCampaignsHint,
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final row = _rows[i];
                      final live = row['is_active'] == true;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(row['title'] as String? ?? ''),
                        subtitle: Text(
                          [
                            live ? t.campaignLive : t.campaignHidden,
                            row['url'] as String? ?? '',
                          ].join(' · '),
                        ),
                        onTap: _busy ? null : () => _edit(row: row),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: live,
                              onChanged: _busy
                                  ? null
                                  : (value) => _run(
                                      () => ref
                                          .read(adminRepositoryProvider)
                                          .updateOffer(row['id'] as int, {
                                            'is_active': value,
                                          }),
                                    ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _busy
                                  ? null
                                  : () => _run(
                                      () => ref
                                          .read(adminRepositoryProvider)
                                          .deleteOffer(row['id'] as int),
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferForm extends StatefulWidget {
  const _OfferForm({this.row});

  final Map<String, dynamic>? row;

  @override
  State<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<_OfferForm> {
  late final _title = TextEditingController(
    text: widget.row?['title'] as String? ?? '',
  );
  late final _subtitle = TextEditingController(
    text: widget.row?['subtitle'] as String? ?? '',
  );
  late final _body = TextEditingController(
    text: widget.row?['body'] as String? ?? '',
  );
  late final _image = TextEditingController(
    text: widget.row?['image_url'] as String? ?? '',
  );
  late final _code = TextEditingController(
    text: widget.row?['promo_code'] as String? ?? '',
  );
  late DateTime? _ends = DateTime.tryParse(
    widget.row?['ends_at'] as String? ?? '',
  );

  @override
  void dispose() {
    for (final c in [_title, _subtitle, _body, _image, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: t.campaignTitle),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subtitle,
              decoration: InputDecoration(labelText: t.campaignSubtitle),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              decoration: InputDecoration(labelText: t.campaignBody),
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _image,
              decoration: InputDecoration(labelText: t.campaignImage),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _code,
              decoration: InputDecoration(labelText: t.promo),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.campaignEnds),
              subtitle: Text(
                _ends == null
                    ? '—'
                    : '${_ends!.day.toString().padLeft(2, '0')}.'
                          '${_ends!.month.toString().padLeft(2, '0')}.${_ends!.year}',
              ),
              trailing: const Icon(Icons.event),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _ends ?? now.add(const Duration(days: 14)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365 * 2)),
                );
                if (picked != null) setState(() => _ends = picked);
              },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _title.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, {
                      'title': _title.text.trim(),
                      'subtitle': _subtitle.text.trim(),
                      'body': _body.text.trim(),
                      'image_url': _image.text.trim().isEmpty
                          ? null
                          : _image.text.trim(),
                      'promo_code': _code.text.trim().isEmpty
                          ? null
                          : _code.text.trim().toUpperCase(),
                      'ends_at': _ends?.toIso8601String(),
                    }),
              child: Text(t.save),
            ),
          ],
        ),
      ),
    );
  }
}
