import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/order_events.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/live_toast.dart';
import '../auth/presentation/auth_controller.dart';
import '../orders/domain/order.dart';

/// Turns WebSocket order events into in-app banners, tailored per role.
/// Keeps the socket alive for the whole session (it's autoDispose otherwise).
class LiveEventsListener extends ConsumerWidget {
  const LiveEventsListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    if (user != null) {
      ref.listen(orderEventsProvider, (prev, next) {
        final evt = next.value;
        if (evt == null || evt == prev?.value) return;
        final order = Order.fromJson(evt.order);
        final router = ref.read(routerProvider);

        if (user.isAdmin) {
          if (order.status == OrderStatus.pending) {
            LiveToast.show(
              icon: Icons.receipt_long,
              title: 'New order #${order.id}',
              body: '${order.restaurantName} · ${order.customer.name}',
              onTap: () => router.go('/admin'),
            );
          }
        } else if (user.isCourier) {
          if (order.courier == null && order.status == OrderStatus.confirmed) {
            LiveToast.show(
              icon: Icons.delivery_dining,
              title: 'Order #${order.id} ready for pickup',
              body: order.address,
              onTap: () => router.go('/courier'),
            );
          }
        } else if (order.customer.id == user.id &&
            order.status != OrderStatus.pending) {
          LiveToast.show(
            icon: Icons.local_dining,
            title: 'Order #${order.id} · ${order.status.label}',
            body: order.courier != null
                ? 'Courier ${order.courier!.name}'
                : order.restaurantName,
            onTap: () => router.push('/orders/${order.id}'),
          );
        }
      });
    }
    return Overlay(
      key: LiveToast.overlayKey,
      initialEntries: [OverlayEntry(builder: (_) => child)],
    );
  }
}
