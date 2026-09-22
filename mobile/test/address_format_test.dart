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
}
