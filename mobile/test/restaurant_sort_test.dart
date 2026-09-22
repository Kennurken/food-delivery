import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/restaurants/domain/restaurant.dart';
import 'package:food_delivery/features/restaurants/domain/sort.dart';

Restaurant r({
  required int id,
  required String name,
  double rating = 4,
  int eta = 30,
  double fee = 500,
}) => Restaurant(
  id: id,
  name: name,
  description: '',
  cuisine: 'X',
  rating: rating,
  ratingCount: 10,
  deliveryFee: fee,
  deliveryTimeMin: eta,
  isOpen: true,
);

void main() {
  final bao = r(id: 1, name: 'Bao', rating: 4.7, eta: 25, fee: 500);
  final pizza = r(id: 2, name: 'Pizza', rating: 4.5, eta: 35, fee: 700);
  final burger = r(id: 3, name: 'Burger', rating: 4.3, eta: 20, fee: 600);
  final list = [pizza, burger, bao];

  test('rating is highest first', () {
    expect(sortRestaurants(list, RestaurantSort.rating).map((e) => e.name), [
      'Bao',
      'Pizza',
      'Burger',
    ]);
  });

  test('eta is fastest first', () {
    expect(sortRestaurants(list, RestaurantSort.eta).map((e) => e.name), [
      'Burger',
      'Bao',
      'Pizza',
    ]);
  });

  test('fee is cheapest delivery first', () {
    expect(sortRestaurants(list, RestaurantSort.fee).map((e) => e.name), [
      'Bao',
      'Burger',
      'Pizza',
    ]);
  });

  test('spotlight is the top-rated slice', () {
    expect(spotlightOf(list, take: 2).map((e) => e.name), ['Bao', 'Pizza']);
  });
}
