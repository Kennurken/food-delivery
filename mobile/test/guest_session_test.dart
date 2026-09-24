import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/auth/domain/user.dart';

void main() {
  group('table guest', () {
    test('a scanned session is marked as one', () {
      final user = User.fromJson({
        'id': 7,
        'email': 'guest.ab12@qr.invalid',
        'name': 'Стол T3',
        'phone': null,
        'role': 'customer',
        'is_guest': true,
      });

      expect(user.isGuest, isTrue);
      expect(user.isAdmin, isFalse);
      expect(user.isCourier, isFalse);
    });

    test('an ordinary customer is not one', () {
      final user = User.fromJson({
        'id': 1,
        'email': 'user@food.dev',
        'name': 'Гость',
        'phone': null,
        'role': 'customer',
      });

      // Absent means false: an older API that does not send the field must not
      // turn every customer into a guest.
      expect(user.isGuest, isFalse);
    });

    test('a guest is still only a customer', () {
      final user = User.fromJson({
        'id': 9,
        'email': 'guest.cd34@qr.invalid',
        'name': 'Стол 5',
        'phone': null,
        'role': 'customer',
        'is_guest': true,
      });

      expect(user.role, 'customer');
    });
  });
}
