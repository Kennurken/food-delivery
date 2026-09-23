import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/admin/data/admin_repository.dart';

void main() {
  Map<String, dynamic> payload({
    String status = 'active',
    String plan = 'pro',
    Object? renews = '2026-10-23T00:00:00',
    bool subscription = true,
  }) => {
    'plan_code': plan,
    'plan_name': 'Pro',
    'monthly_price': 29000,
    'billed': true,
    'billing_status': status,
    'renews_at': renews,
    'has_subscription': subscription,
    'billing_enabled': true,
  };

  group('venue billing', () {
    test('a failed renewal is a warning, not a closure', () {
      final data = VenueBilling.fromJson(payload(status: 'past_due'));

      expect(data.isRetrying, isTrue);
      expect(data.isBlocked, isFalse);
    });

    test('an unpaid subscription does block', () {
      expect(
        VenueBilling.fromJson(payload(status: 'suspended')).isBlocked,
        isTrue,
      );
      expect(
        VenueBilling.fromJson(payload(status: 'cancelled')).isBlocked,
        isTrue,
      );
      expect(
        VenueBilling.fromJson(payload(status: 'expired')).isBlocked,
        isTrue,
      );
    });

    test('an active subscription is neither', () {
      final data = VenueBilling.fromJson(payload());

      expect(data.isRetrying, isFalse);
      expect(data.isBlocked, isFalse);
    });

    test('a missing renewal date stays null rather than becoming today', () {
      final data = VenueBilling.fromJson(payload(renews: null));

      expect(data.renewsAt, isNull);
    });

    test('the renewal date survives the round trip', () {
      final data = VenueBilling.fromJson(payload());

      expect(data.renewsAt?.year, 2026);
      expect(data.renewsAt?.month, 10);
    });

    test('survives an empty payload without claiming a subscription', () {
      final data = VenueBilling.fromJson({});

      expect(data.hasSubscription, isFalse);
      expect(data.billed, isFalse);
      expect(data.billingEnabled, isFalse);
      expect(data.isBlocked, isFalse);
    });
  });

  group('billing plans', () {
    test('a free plan is not sold', () {
      final plan = BillingPlan.fromJson({
        'code': 'basic',
        'name': 'Basic',
        'monthly_price': 0,
        'billed': false,
      });

      expect(plan.billed, isFalse);
      expect(plan.monthlyPrice, 0);
    });

    test('a paid plan carries its price', () {
      final plan = BillingPlan.fromJson({
        'code': 'premium',
        'name': 'Premium',
        'monthly_price': 79000,
        'billed': true,
      });

      expect(plan.billed, isTrue);
      expect(plan.monthlyPrice, 79000);
    });
  });
}
