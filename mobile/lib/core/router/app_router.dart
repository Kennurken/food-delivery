import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/restaurants/presentation/home_screen.dart';
import '../../features/restaurants/presentation/restaurant_screen.dart';

/// Bridges Riverpod auth state to GoRouter's refreshListenable.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading) return '/splash';

      final signedIn = auth.value != null;
      final onAuthPage = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!signedIn && !onAuthPage) return '/login';
      if (signedIn && (onAuthPage || state.matchedLocation == '/splash')) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/restaurants/:id',
        builder: (_, s) => RestaurantScreen(id: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
      GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
      GoRoute(
        path: '/orders/:id',
        builder: (_, s) => OrderDetailScreen(id: int.parse(s.pathParameters['id']!)),
      ),
    ],
  );
});
