import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/reservations/domain/reservation.dart';
import 'package:food_delivery/features/restaurants/domain/restaurant.dart';

void main() {
  test('restaurant flag is off unless the API says so', () {
    final r = Restaurant.fromJson({
      'id': 1,
      'name': 'Bao',
      'description': '',
      'cuisine': 'Asian',
      'rating': 4.5,
      'rating_count': 10,
      'delivery_fee': 500,
      'delivery_time_min': 25,
      'is_open': true,
    });
    expect(r.allowsReservations, isFalse);
    final pro = Restaurant.fromJson({
      'id': 1,
      'name': 'Bao',
      'description': '',
      'cuisine': 'Asian',
      'rating': 4.5,
      'rating_count': 10,
      'delivery_fee': 500,
      'delivery_time_min': 25,
      'is_open': true,
      'reservations': true,
    });
    expect(pro.allowsReservations, isTrue);
  });

  test('confirmed bookings can be cancelled, seated cannot', () {
    Reservation row(String status) => Reservation.fromJson({
      'id': 1,
      'restaurant_id': 1,
      'restaurant_name': 'Bao House',
      'name': 'Aida',
      'guests': 2,
      'starts_at': '2026-09-22T18:00:00',
      'duration_min': 90,
      'status': status,
    });
    expect(row('confirmed').canCancel, isTrue);
    expect(row('requested').canCancel, isTrue);
    expect(row('seated').canCancel, isFalse);
    expect(row('cancelled').canCancel, isFalse);
  });
}
