import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/admin/data/admin_repository.dart';

void main() {
  group('venue settings', () {
    Map<String, dynamic> row(String key, bool inPlan, bool? override) => {
      'key': key,
      'in_plan': inPlan,
      'override': override,
      'enabled': override ?? inPlan,
    };

    test('a plan feature reads as inherited, not as forced', () {
      final data = VenueSettings.fromJson({
        'plan_code': 'pro',
        'limits': {'staff.max': 30},
        'features': [row('catalog', true, null)],
      });

      final feature = data.features.single;
      expect(feature.inPlan, isTrue);
      expect(feature.override, isNull);
      expect(feature.enabled, isTrue);
    });

    test('forced off is distinguishable from simply not in the plan', () {
      final data = VenueSettings.fromJson({
        'plan_code': 'pro',
        'limits': const {},
        'features': [
          row('reservations', true, false),
          row('inventory', false, null),
        ],
      });

      final forced = data.features.first;
      final absent = data.features.last;
      expect(forced.enabled, isFalse);
      expect(absent.enabled, isFalse);
      // Same effect, different cause — only one of them follows a plan change.
      expect(forced.override, isFalse);
      expect(absent.override, isNull);
    });

    test('an unlimited limit survives as null rather than zero', () {
      final data = VenueSettings.fromJson({
        'plan_code': 'premium',
        'limits': {'staff.max': null, 'tables.max': 100},
        'features': const [],
      });

      expect(data.limits['staff.max'], isNull);
      expect(data.limits['tables.max'], 100);
    });

    test('survives an empty payload', () {
      final data = VenueSettings.fromJson({});

      expect(data.planCode, '');
      expect(data.features, isEmpty);
      expect(data.limits, isEmpty);
    });
  });
}
