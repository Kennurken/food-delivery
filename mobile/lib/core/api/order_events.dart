import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../storage/token_storage.dart';
import 'api_config.dart';

/// One frame from `/api/v1/ws`.
class OrderEvent {
  const OrderEvent({this.order, this.chat, this.cause = 'status'});

  final Map<String, dynamic>? order;
  final Map<String, dynamic>? chat;
  final String cause;

  int get id => (order?['id'] as int?) ?? chat!['order_id'] as int;
  bool get isLocation => cause == 'location';
  bool get isChat => cause == 'chat';
  bool get isQuiet => isLocation || isChat;
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
          final type = msg['type'] as String?;
          if (type == 'order.updated') {
            controller.add(
              OrderEvent(
                order: msg['order'] as Map<String, dynamic>,
                cause: msg['cause'] as String? ?? 'status',
              ),
            );
          } else if (type == 'order.chat') {
            controller.add(
              OrderEvent(
                chat: msg['message'] as Map<String, dynamic>,
                cause: 'chat',
              ),
            );
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
