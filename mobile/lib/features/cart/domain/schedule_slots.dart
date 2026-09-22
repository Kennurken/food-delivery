/// 15-minute slots, local clock. Kitchen hours 10:00–22:00.
List<DateTime> scheduleSlots(
  DateTime now, {
  int minMinutes = 45,
  int days = 2,
}) {
  var cursor = now.add(Duration(minutes: minMinutes));
  final bump = (15 - cursor.minute % 15) % 15;
  cursor = DateTime(
    cursor.year,
    cursor.month,
    cursor.day,
    cursor.hour,
    cursor.minute,
  ).add(Duration(minutes: bump));
  final last = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(days: days, hours: 22));
  final out = <DateTime>[];
  for (
    var t = cursor;
    !t.isAfter(last);
    t = t.add(const Duration(minutes: 15))
  ) {
    if (t.hour >= 10 && t.hour < 22) out.add(t);
  }
  return out;
}

String formatSlot(DateTime t) {
  final d = t.day.toString().padLeft(2, '0');
  final mo = t.month.toString().padLeft(2, '0');
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$d.$mo $h:$m';
}
