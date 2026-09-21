import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../storage/token_storage.dart';
import 'api_config.dart';

/// One `order.updated` frame from the server.
class OrderEvent {
  const OrderEvent(this.order);

  final Map<String, dynamic> order;

  int get id => order['id'] as int;
}

/// Long-lived WebSocket to /api/v1/ws. Reconnects with backoff; ends when
/// the last listener goes away (autoDispose).
final orderEventsProvider = StreamProvider.autoDispose<OrderEvent>((ref) {
  final controller = StreamController<OrderEvent>();
  var closed = false;
  WebSocketChannel? channel;

  Future<void> run() async {
    var delay = const Duration(seconds: 1);
    while (!closed) {
      final token = await ref.read(tokenStorageProvider).read();
      if (token == null) return;
      final uri = Uri.parse(
        '${ApiConfig.baseUrl.replaceFirst('http', 'ws')}/api/v1/ws?token=$token',
      );
      try {
        channel = WebSocketChannel.connect(uri);
        await channel!.ready;
        delay = const Duration(seconds: 1);
        await for (final frame in channel!.stream) {
          final msg = jsonDecode(frame as String) as Map<String, dynamic>;
          if (msg['type'] == 'order.updated') {
            controller.add(OrderEvent(msg['order'] as Map<String, dynamic>));
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('ws: $e');
      }
      if (closed) break;
      await Future<void>.delayed(delay);
      delay = delay * 2 > const Duration(seconds: 30)
          ? const Duration(seconds: 30)
          : delay * 2;
    }
  }

  run();
  ref.onDispose(() {
    closed = true;
    channel?.sink.close();
    controller.close();
  });
  return controller.stream;
});
