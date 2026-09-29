import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/utils/server_time.dart';

void main() {
  test('a zoneless API timestamp is UTC, returned as local time', () {
    final t = parseServerTime('2026-09-30T07:40:00')!;

    expect(t.isUtc, isFalse);
    expect(t.toUtc(), DateTime.utc(2026, 9, 30, 7, 40));
  });

  test('a timestamp with a zone keeps it', () {
    expect(
      parseServerTime('2026-10-01T10:00:00+05:00')!.toUtc(),
      DateTime.utc(2026, 10, 1, 5),
    );
    expect(
      parseServerTime('2026-10-01T05:00:00Z')!.toUtc(),
      DateTime.utc(2026, 10, 1, 5),
    );
  });

  test('fractional seconds are fine', () {
    expect(
      parseServerTime('2026-09-30T07:40:00.123456')!.toUtc(),
      DateTime.utc(2026, 9, 30, 7, 40, 0, 123, 456),
    );
  });

  test('missing or junk is null, not a crash', () {
    expect(parseServerTime(null), isNull);
    expect(parseServerTime(''), isNull);
    expect(parseServerTime('not a date'), isNull);
  });
}
