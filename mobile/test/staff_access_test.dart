import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/router/app_router.dart';
import 'package:food_delivery/features/auth/domain/user.dart';
import 'package:food_delivery/features/profile/data/profile_repository.dart';

const _customer = User(id: 1, email: 'c@x.kz', name: 'C', role: 'customer');
const _admin = User(id: 2, email: 'a@x.kz', name: 'A', role: 'admin');
const _courier = User(id: 3, email: 'r@x.kz', name: 'R', role: 'courier');

void main() {
  group('who may stand where', () {
    test("a venue's staff (customers with a membership) reach its screens", () {
      for (final path in [
        '/admin/restaurants/5',
        '/admin/restaurants/5/kitchen',
        '/admin/restaurants/5/floor',
        '/admin/restaurants/5/stats',
      ]) {
        expect(roleAllows(_customer, path), isTrue, reason: path);
      }
    });

    test('but not the platform screens', () {
      expect(roleAllows(_customer, '/admin'), isFalse);
      expect(roleAllows(_customer, '/admin/platform/restaurants/5'), isFalse);
      expect(roleAllows(_customer, '/courier'), isFalse);
    });

    test('platform admins and couriers keep their rules', () {
      expect(roleAllows(_admin, '/admin/restaurants/5'), isTrue);
      expect(roleAllows(_admin, '/'), isFalse);
      expect(roleAllows(_courier, '/admin/restaurants/5'), isFalse);
    });
  });

  test('memberships list only the active venues', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) => h.resolve(
            Response(
              requestOptions: o,
              statusCode: 200,
              data: [
                {
                  'restaurant_id': 5,
                  'name': 'Bao',
                  'role': 'owner',
                  'is_active': true,
                },
                {
                  'restaurant_id': 6,
                  'name': 'Old',
                  'role': 'kitchen',
                  'is_active': false,
                },
              ],
            ),
          ),
        ),
      );

    final venues = await ProfileRepository(dio).memberships();

    expect(venues.map((v) => (v.restaurantId, v.role)), [(5, 'owner')]);
  });
}
