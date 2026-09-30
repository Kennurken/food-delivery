import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/utils/haptics.dart';
import '../../loyalty/data/loyalty_repository.dart';

/// The venue's bonus programme: the rate, and how much of an order bonuses may
/// pay. Switching it on is a Premium feature; the server says so with a 403.
Future<void> editLoyalty(
  BuildContext context,
  WidgetRef ref,
  int restaurantId, {
  double percent = 0,
  double maxShare = 0.5,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => LoyaltySheet(
      restaurantId: restaurantId,
      percent: percent,
      maxShare: maxShare,
    ),
  );
}

class LoyaltySheet extends ConsumerStatefulWidget {
  const LoyaltySheet({
    super.key,
    required this.restaurantId,
    this.percent = 0,
    this.maxShare = 0.5,
  });

  final int restaurantId;
  final double percent;
  final double maxShare;

  @override
  ConsumerState<LoyaltySheet> createState() => _LoyaltySheetState();
}

class _LoyaltySheetState extends ConsumerState<LoyaltySheet> {
  late final _percent = TextEditingController(text: _fmt(widget.percent));
  late final _share = TextEditingController(text: _fmt(widget.maxShare * 100));
  var _busy = false;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _percent.dispose();
    _share.dispose();
    super.dispose();
  }

  double? _read(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final percent = _read(_percent);
    final share = _read(_share);
    final t = context.l10n;
    // The server holds the same limits; checking here spares a round trip and
    // says what is wrong next to the field instead of as a 422.
    if (percent == null || percent < 0 || percent > 30) {
      _say(t.bonusPercent);
      return;
    }
    if (share == null || share < 0 || share > 100) {
      _say(t.bonusMaxShare);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(loyaltyRepositoryProvider)
          .saveProgramme(
            widget.restaurantId,
            percent: percent,
            maxShare: share / 100,
          );
      Haptics.success();
      if (mounted) Navigator.pop(context);
    } on DioException catch (e) {
      _say(e.response?.statusCode == 403 ? t.premiumOnly : errorMessage(e));
    } catch (e) {
      _say(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
            Text(
              t.bonusProgramme,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _percent,
              decoration: InputDecoration(
                labelText: t.bonusPercent,
                suffixText: '%',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _share,
              decoration: InputDecoration(
                labelText: t.bonusMaxShare,
                suffixText: '%',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: Text(t.save)),
          ],
        ),
      ),
    );
  }
}
