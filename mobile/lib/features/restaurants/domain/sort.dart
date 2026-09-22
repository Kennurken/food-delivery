import '../domain/restaurant.dart';

enum RestaurantSort { rating, eta, fee }

List<Restaurant> sortRestaurants(List<Restaurant> list, RestaurantSort sort) {
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
  }
  return next;
}

/// Top-rated slice for the Swiggy-style spotlight row.
List<Restaurant> spotlightOf(List<Restaurant> list, {int take = 3}) =>
    sortRestaurants(list, RestaurantSort.rating).take(take).toList();
