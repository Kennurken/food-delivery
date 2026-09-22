import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/admin/domain/platform_venue.dart';

void main() {
  const row = {
    'id': 1,
    'name': 'Bao Bar',
    'cuisine': 'Asian',
    'image_url': 'https://example.test/a.jpg',
    'is_open': true,
    'plan_code': 'pro',
    'billing_status': 'active',
    'rating': 4.64,
    'rating_count': 11,
    'owner': {
      'id': 7,
      'name': 'Aigerim Suleimen',
      'email': 'owner.bao@food.dev',
      'phone': '+77012345001',
      'role': 'owner',
    },
    'staff_count': 1,
    'orders_total': 8,
    'orders_window': 8,
    'revenue_total': 12300.0,
    'revenue_window': 12300.0,
    'last_order_at': '2026-09-22T17:42:03',
    'window_days': 30,
  };

  test('parses the directory row a platform admin reads', () {
    final v = PlatformVenue.fromJson(Map<String, dynamic>.from(row));
    expect(v.name, 'Bao Bar');
    expect(v.planCode, 'pro');
    expect(v.owner!.name, 'Aigerim Suleimen');
    expect(v.owner!.role, 'owner');
    expect(v.revenueWindow, 12300.0);
    expect(v.lastOrderAt!.day, 22);
    expect(v.hasContact, isTrue);
  });

  test('a tenant with no owner is flagged as unreachable, not crashed on', () {
    final json = Map<String, dynamic>.from(row)..['owner'] = null;
    final v = PlatformVenue.fromJson(json);
    expect(v.owner, isNull);
    expect(v.hasContact, isFalse);
  });

  test('missing numbers fall back to zero instead of throwing', () {
    final v = PlatformVenue.fromJson({
      'id': 2,
      'name': 'New venue',
      'is_open': false,
    });
    expect(v.ordersTotal, 0);
    expect(v.revenueTotal, 0);
    expect(v.windowDays, 30);
    expect(v.staff, isEmpty);
    expect(v.recentOrders, isEmpty);
  });

  test('an owner with neither phone nor email is not reachable', () {
    final contact = PlatformContact.fromJson({
      'id': 9,
      'name': 'Ghost',
      'email': '',
      'role': 'owner',
    });
    expect(contact.reachable, isFalse);
  });

  test('detail payload carries staff and recent orders', () {
    final json = Map<String, dynamic>.from(row)
      ..['staff'] = [
        {
          'id': 7,
          'name': 'Aigerim Suleimen',
          'email': 'owner.bao@food.dev',
          'phone': '+77012345001',
          'role': 'owner',
          'is_active': true,
          'since': '2026-09-22T10:00:00',
        },
      ]
      ..['recent_orders'] = [
        {
          'id': 10,
          'status': 'cancelled',
          'channel': 'delivery',
          'total': 3100.0,
          'pay_method': 'online',
          'pay_status': 'refunded',
          'created_at': '2026-09-22T17:42:03',
        },
      ];
    final v = PlatformVenue.fromJson(json);
    expect(v.staff.single.role, 'owner');
    expect(v.recentOrders.single.payStatus, 'refunded');
  });
}
