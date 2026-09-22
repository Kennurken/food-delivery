import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/map/domain/geo.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('Almaty Republic Square is the default camera', () {
    expect(almatyCenter.latitude, closeTo(43.238949, 0.00001));
    expect(almatyCenter.longitude, closeTo(76.945465, 0.00001));
  });

  test('haversine is zero at the same point', () {
    expect(metersBetween(almatyCenter, almatyCenter), 0);
  });

  test('Abay to Dostyk is a few kilometres', () {
    final abay = LatLng(43.25654, 76.92812);
    final dostyk = LatLng(43.23800, 76.94547);
    final m = metersBetween(abay, dostyk);
    expect(m, greaterThan(2000));
    expect(m, lessThan(4000));
  });

  test('rejects the null island pin', () {
    expect(hasPin(0, 0), isFalse);
    expect(hasPin(43.2, 76.9), isTrue);
    expect(hasPin(null, 76.9), isFalse);
  });
}
