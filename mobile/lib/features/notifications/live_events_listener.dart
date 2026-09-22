import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/order_events.dart';
import '../../core/l10n/l10n.dart';
import '../../core/router/app_router.dart';
import '../../core/widgets/live_toast.dart';
import '../auth/presentation/auth_controller.dart';
import '../orders/domain/order.dart';
import 'local_push.dart';

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
        final router = ref.read(routerProvider);
        final t = context.l10n;
        if (evt.isChat) {
          final chat = evt.chat;
          if (chat == null) return;
          final uid = chat['user_id'] as int?;
          if (uid == user.id) return;
          final path = router.routeInformationProvider.value.uri.path;
          if (path == '/chat/${evt.id}') return;
          final who = chat['sender_name'] as String? ?? '';
          final body = chat['body'] as String? ?? '';
          LiveToast.show(
            icon: Icons.chat_bubble_outline,
            title: t.orderN(evt.id),
            body: t.chatPreview(who, body),
            onTap: () => router.push('/chat/${evt.id}'),
          );
          unawaited(
            LocalPush.show(
              title: t.orderN(evt.id),
              body: t.chatPreview(who, body),
            ),
          );
          return;
        }
        if (evt.isLocation) return;
        final order = Order.fromJson(evt.order!);

        if (user.isAdmin) {
          if (order.status == OrderStatus.pending) {
            LiveToast.show(
              icon: Icons.receipt_long,
              title: t.toastNewOrder(order.id),
              body: '${order.restaurantName} · ${order.customer.name}',
              onTap: () =>
                  router.go('/admin/restaurants/${order.restaurantId}/kitchen'),
            );
            unawaited(
              LocalPush.show(
                title: t.toastNewOrder(order.id),
                body: '${order.restaurantName} · ${order.customer.name}',
              ),
            );
          }
        } else if (user.isCourier) {
          if (order.isDelivery &&
              order.courier == null &&
              order.status == OrderStatus.confirmed) {
            LiveToast.show(
              icon: Icons.delivery_dining,
              title: t.toastReadyForPickup(order.id),
              body: order.address,
              onTap: () => router.go('/courier'),
            );
            unawaited(
              LocalPush.show(
                title: t.toastReadyForPickup(order.id),
                body: order.address,
              ),
            );
          }
        } else if (order.customer.id == user.id &&
            order.status != OrderStatus.pending) {
          LiveToast.show(
            icon: Icons.local_dining,
            title: '${t.orderN(order.id)} · ${order.statusLabel(t)}',
            body: order.courier != null
                ? t.toastCourier(order.courier!.name)
                : order.restaurantName,
            onTap: () => router.push('/orders/${order.id}'),
          );
          unawaited(
            LocalPush.show(
              title: '${t.orderN(order.id)} · ${order.statusLabel(t)}',
              body: order.courier != null
                  ? t.toastCourier(order.courier!.name)
                  : order.restaurantName,
            ),
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
