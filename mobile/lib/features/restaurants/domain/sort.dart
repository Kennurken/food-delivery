import 'package:latlong2/latlong.dart';

import '../../map/domain/geo.dart';
import '../domain/restaurant.dart';

enum RestaurantSort { rating, eta, fee, near }

List<Restaurant> sortRestaurants(
  List<Restaurant> list,
  RestaurantSort sort, {
  LatLng? origin,
}) {
  final next = [...list];
  switch (sort) {
    case RestaurantSort.rating:
      next.sort((a, b) {
        final byRating = b.rating.compareTo(a.rating);
        return byRating != 0 ? byRating : a.id.compareTo(b.id);
      });
    case RestaurantSort.eta:
      next.sort((a, b) {
        final byEta = a.deliveryTimeMin.compareTo(b.deliveryTimeMin);
        return byEta != 0 ? byEta : a.id.compareTo(b.id);
      });
    case RestaurantSort.fee:
      next.sort((a, b) {
        final byFee = a.deliveryFee.compareTo(b.deliveryFee);
        return byFee != 0 ? byFee : a.id.compareTo(b.id);
      });
    case RestaurantSort.near:
      if (origin == null) {
        next.sort((a, b) {
          final byRating = b.rating.compareTo(a.rating);
          return byRating != 0 ? byRating : a.id.compareTo(b.id);
        });
        break;
      }
      next.sort((a, b) {
        final da = _meters(origin, a);
        final db = _meters(origin, b);
        final byDist = da.compareTo(db);
        return byDist != 0 ? byDist : a.id.compareTo(b.id);
      });
  }
  return next;
}

double _meters(LatLng origin, Restaurant r) {
  if (!r.hasPin) return double.infinity;
  return metersBetween(origin, LatLng(r.lat!, r.lng!));
}

/// Top-rated slice for the Swiggy-style spotlight row.
List<Restaurant> spotlightOf(List<Restaurant> list, {int take = 3}) =>
    sortRestaurants(list, RestaurantSort.rating).take(take).toList();
