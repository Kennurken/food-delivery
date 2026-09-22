import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/cart/domain/schedule_slots.dart';

void main() {
  test('first slot is at least 45 minutes out and on a 15-minute mark', () {
    final now = DateTime(2026, 9, 22, 12, 7);
    final slots = scheduleSlots(now);
    expect(slots, isNotEmpty);
    expect(slots.first.isAfter(now.add(const Duration(minutes: 44))), isTrue);
    expect(slots.first.minute % 15, 0);
    expect(slots.every((s) => s.hour >= 10 && s.hour < 22), isTrue);
  });

  test('late evening rolls to tomorrow morning', () {
    final now = DateTime(2026, 9, 22, 21, 50);
    final slots = scheduleSlots(now);
    expect(slots, isNotEmpty);
    expect(slots.first.day, 23);
    expect(slots.first.hour, greaterThanOrEqualTo(10));
  });

  test('reservation slots cover two weeks of evenings', () {
    final now = DateTime(2026, 9, 22, 12, 0);
    final slots = reservationSlots(now);
    expect(slots, isNotEmpty);
    expect(slots.last.difference(now).inDays, greaterThanOrEqualTo(10));
    expect(slots.first.isAfter(now.add(const Duration(minutes: 44))), isTrue);
  });
}
