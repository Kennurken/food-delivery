import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/profile/domain/address.dart';

void main() {
  test('street only', () {
    expect(formatAddress('Abay 10'), 'Abay 10');
  });

  test('joins KZ extras in order', () {
    expect(
      formatAddress(
        'Abay 10',
        apt: '12',
        entrance: '2',
        floor: '4',
        intercom: '12#',
      ),
      'Abay 10, apt 12, ent. 2, fl. 4, intercom 12#',
    );
  });

  test('skips blanks', () {
    expect(formatAddress('Dostyk 1', apt: '  ', floor: '3'), 'Dostyk 1, fl. 3');
  });

  group('a saved address knows whether it can be delivered to precisely', () {
    Address make({double? lat, double? lng}) => Address.fromJson({
      'id': 1,
      'label': 'Home',
      'line': 'Abay 10',
      'is_default': true,
      'lat': lat,
      'lng': lng,
    });

    test('text-only address has no pin, so pricing must not trust it', () {
      expect(make().hasPin, isFalse);
    });

    test('Null Island is not a delivery address', () {
      expect(make(lat: 0, lng: 0).hasPin, isFalse);
    });

    test('a real point counts', () {
      expect(make(lat: 43.2389, lng: 76.9455).hasPin, isTrue);
    });

    test('an out-of-range coordinate is rejected', () {
      expect(make(lat: 100, lng: 76.9).hasPin, isFalse);
    });
  });
}
