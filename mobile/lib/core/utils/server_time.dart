/// Reads a timestamp from the API.
///
/// The API sends UTC without a zone ("2026-09-30T07:40:00"): the database
/// columns are naive. `DateTime.parse` takes such a string as *local* time, so
/// every clock in the app ran five hours early in Almaty. This reads it as
/// UTC and returns local time. A string that carries a zone is honoured as is.
DateTime? parseServerTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final zoned = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(raw);
  return DateTime.tryParse(zoned ? raw : '${raw}Z')?.toLocal();
}
