import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../loyalty/data/loyalty_repository.dart';
import '../../loyalty/domain/loyalty.dart';
import 'cart_controller.dart';

/// What the venue's bonus programme would let this cart use, or null when
/// there is nothing to show: no venue yet, a guest, no balance, or the
/// server can't be asked. A bonus tile that fails should simply not appear —
/// it must never stand between someone and checkout.
final cartLoyaltyQuoteProvider = FutureProvider.autoDispose<LoyaltyQuote?>((
  ref,
) async {
  final cart = ref.watch(cartProvider);
  final venue = cart.restaurantId;
  if (venue == null || cart.isEmpty) return null;
  final food = (cart.subtotal - cart.promoDiscount).clamp(0, double.infinity);
  try {
    final quote = await ref
        .watch(loyaltyRepositoryProvider)
        .quote(venue, subtotal: food.toDouble());
    return quote.hasUsable ? quote : null;
  } catch (_) {
    return null;
  }
});

/// Tenge of bonuses this cart will spend: only when the diner switched it on.
/// A preview — the server decides the real amount when the order is placed.
final cartLoyaltyUsedProvider = Provider.autoDispose<double>((ref) {
  if (!ref.watch(cartProvider.select((c) => c.useLoyalty))) return 0;
  return ref.watch(cartLoyaltyQuoteProvider).value?.usable ?? 0;
});
