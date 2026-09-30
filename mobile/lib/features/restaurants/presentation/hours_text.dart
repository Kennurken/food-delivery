import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/restaurant.dart';
import '../../../core/l10n/l10n.dart';

/// Returns a label like "Opens at 10:00" or "Opens Mon, 10:00" when the venue
/// is switched on but currently closed by hours. Null otherwise (open now,
/// or the owner has the switch off).
String? opensLabel(BuildContext context, Restaurant r, {DateTime? now}) {
  now ??= DateTime.now();
  // Only show when switched on AND closed by hours (not accepting orders because of hours)
  if (!r.isOpen || r.openNow || r.opensAt == null) return null;

  final opensAt = r.opensAt!;
  final t = context.l10n;
  final localeName = Localizations.localeOf(context).toLanguageTag();
  final timeStr = DateFormat('HH:mm', localeName).format(opensAt);

  // Same calendar day?
  final sameDay =
      now.year == opensAt.year &&
      now.month == opensAt.month &&
      now.day == opensAt.day;

  if (sameDay) {
    return t.opensAt(timeStr);
  } else {
    final dayStr = DateFormat.E(localeName).format(opensAt);
    return t.opensOnDay(dayStr, timeStr);
  }
}
