import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/orders/data/order_repository.dart';
import 'package:food_delivery/features/orders/domain/chat_message.dart';

void main() {
  test('a message with no kind is plain text', () {
    final m = ChatMessage.fromJson({
      'id': 1,
      'order_id': 2,
      'user_id': 3,
      'sender_name': 'A',
      'body': 'hi',
      'created_at': '2026-10-02T10:00:00',
    });

    expect(m.isEscalation, isFalse);
  });

  test('an escalation line is recognised', () {
    final m = ChatMessage.fromJson({
      'id': 1,
      'order_id': 2,
      'sender_name': 'Aidos',
      'body': 'escalated',
      'kind': 'escalation',
      'created_at': '2026-10-02T10:00:00',
    });

    expect(m.isEscalation, isTrue);
  });

  test('calling the manager posts to the escalate endpoint', () async {
    final log = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            log.add(o);
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 201,
                data: {
                  'id': 9,
                  'order_id': 5,
                  'sender_name': 'Aidos',
                  'body': 'escalated',
                  'kind': 'escalation',
                  'created_at': '2026-10-02T10:00:00',
                },
              ),
            );
          },
        ),
      );

    final msg = await OrderRepository(dio).callManager(5);

    expect(log.single.path, '/api/v1/orders/5/messages/escalate');
    expect(msg.isEscalation, isTrue);
  });
}
