import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/restaurants/data/restaurant_repository.dart';
import 'package:food_delivery/features/restaurants/domain/delivery_quote.dart';

void main() {
  test('parses a metered quote the cart can explain', () {
    final q = DeliveryQuote.fromJson({
      'fee': 640.0,
      'base_fee': 500.0,
      'per_km': 120.0,
      'free_km': 2.0,
      'distance_km': 3.13,
      'max_km': 15.0,
      'out_of_range': false,
    });
    expect(q.fee, 640.0);
    expect(q.isMetered, isTrue);
    expect(q.outOfRange, isFalse);
  });

  test('a flat-fee restaurant is not explained as metered', () {
    final q = DeliveryQuote.fromJson({
      'fee': 500.0,
      'base_fee': 500.0,
      'per_km': 0.0,
      'free_km': 0.0,
      'distance_km': 3.1,
      'out_of_range': false,
    });
    expect(q.isMetered, isFalse);
  });

  test('a quote without a distance is not metered either', () {
    final q = DeliveryQuote.fromJson({
      'fee': 500.0,
      'base_fee': 500.0,
      'per_km': 120.0,
      'out_of_range': false,
    });
    expect(q.distanceKm, isNull);
    expect(q.isMetered, isFalse);
  });

  test('out of range survives the round trip', () {
    final q = DeliveryQuote.fromJson({
      'fee': 3560.0,
      'base_fee': 500.0,
      'per_km': 120.0,
      'distance_km': 27.51,
      'max_km': 15.0,
      'out_of_range': true,
    });
    expect(q.outOfRange, isTrue);
    expect(q.maxKm, 15.0);
  });

  group('DeliveryTarget', () {
    test('needs a point or a settled address before quoting', () {
      expect(const DeliveryTarget(restaurantId: 1).hasTarget, isFalse);
      expect(
        const DeliveryTarget(restaurantId: 1, address: 'ab').hasTarget,
        isFalse,
      );
      expect(
        const DeliveryTarget(restaurantId: 1, address: 'Abay 10').hasTarget,
        isTrue,
      );
      expect(
        const DeliveryTarget(restaurantId: 1, lat: 43.2, lng: 76.9).hasTarget,
        isTrue,
      );
    });

    test('equal targets reuse the same cached quote', () {
      const a = DeliveryTarget(restaurantId: 1, lat: 43.2, lng: 76.9);
      const b = DeliveryTarget(restaurantId: 1, lat: 43.2, lng: 76.9);
      const c = DeliveryTarget(restaurantId: 1, lat: 43.3, lng: 76.9);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  test('an imprecise quote is never explained as a measured distance', () {
    final q = DeliveryQuote.fromJson({
      'fee': 500.0,
      'base_fee': 500.0,
      'per_km': 120.0,
      'distance_km': null,
      'out_of_range': false,
      'precise': false,
    });
    expect(q.precise, isFalse);
    expect(q.isMetered, isFalse);
    expect(q.fee, 500.0);
  });

  test('precise defaults to true for older payloads', () {
    final q = DeliveryQuote.fromJson({'fee': 500.0, 'out_of_range': false});
    expect(q.precise, isTrue);
  });
}
