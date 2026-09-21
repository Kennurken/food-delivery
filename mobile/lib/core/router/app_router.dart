import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_menu_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/courier/presentation/courier_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
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

      final user = auth.value;
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/register';

      if (user == null) return onAuthPage ? null : '/login';

      // Each role has its own surface; keep them there.
      final home = user.isAdmin
          ? '/admin'
          : user.isCourier
          ? '/courier'
          : '/';
      if (onAuthPage || loc == '/splash') return home;
      final onCourier = loc.startsWith('/courier');
      final onAdmin = loc.startsWith('/admin');
      if (user.isAdmin && !onAdmin) return home;
      if (user.isCourier && !onCourier) return home;
      final isCustomer = !user.isAdmin && !user.isCourier;
      if (isCustomer && (onAdmin || onCourier)) return home;
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/courier', builder: (_, _) => const CourierScreen()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
      GoRoute(
        path: '/admin/restaurants/:id',
        builder: (_, s) =>
            AdminMenuScreen(restaurantId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/restaurants/:id',
        builder: (_, s) =>
            RestaurantScreen(id: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
      GoRoute(
        path: '/orders/:id',
        builder: (_, s) =>
            OrderDetailScreen(id: int.parse(s.pathParameters['id']!)),
      ),
    ],
  );
});
