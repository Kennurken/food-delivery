import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/floor_plan/presentation/floor_plan_screen.dart';
import '../../features/admin/presentation/admin_menu_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/admin/presentation/kitchen_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/courier/presentation/courier_screen.dart';
import '../../features/orders/presentation/order_detail_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/restaurants/presentation/home_screen.dart';
import '../../features/restaurants/presentation/qr_table_screen.dart';
import '../../features/restaurants/presentation/restaurant_screen.dart';
import '../../features/shell/customer_shell.dart';

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
      final onQr = loc.startsWith('/t/');

      if (user == null) {
        if (onAuthPage || onQr) return null;
        final next = Uri.encodeComponent(state.uri.toString());
        return '/login?next=$next';
      }

      // Each role has its own surface; keep them there.
      final home = user.isAdmin
          ? '/admin'
          : user.isCourier
          ? '/courier'
          : '/';
      if (onAuthPage || loc == '/splash') {
        final next = state.uri.queryParameters['next'];
        if (next != null &&
            next.startsWith('/') &&
            !next.startsWith('/admin') &&
            !next.startsWith('/courier') &&
            !next.startsWith('/login')) {
          return next;
        }
        return home;
      }
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
      GoRoute(
        path: '/t/:token',
        builder: (_, s) => QrTableScreen(token: s.pathParameters['token']!),
      ),
      GoRoute(path: '/courier', builder: (_, _) => const CourierScreen()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
      GoRoute(
        path: '/admin/restaurants/:id',
        builder: (_, s) =>
            AdminMenuScreen(restaurantId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/admin/restaurants/:id/floor',
        builder: (_, s) =>
            FloorPlanScreen(restaurantId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/admin/restaurants/:id/kitchen',
        builder: (_, s) =>
            KitchenScreen(restaurantId: int.parse(s.pathParameters['id']!)),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            CustomerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
              GoRoute(
                path: '/restaurants/:id',
                builder: (_, s) =>
                    RestaurantScreen(id: int.parse(s.pathParameters['id']!)),
              ),
              GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
              GoRoute(
                path: '/orders/:id',
                builder: (_, s) =>
                    OrderDetailScreen(id: int.parse(s.pathParameters['id']!)),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
