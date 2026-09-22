import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/features/orders/domain/chat_message.dart';

void main() {
  test('parses a chat line', () {
    final msg = ChatMessage.fromJson({
      'id': 7,
      'order_id': 3,
      'user_id': 2,
      'sender_name': 'Cook',
      'body': 'on it',
      'created_at': '2026-09-22T12:00:00',
    });
    expect(msg.id, 7);
    expect(msg.orderId, 3);
    expect(msg.userId, 2);
    expect(msg.senderName, 'Cook');
    expect(msg.body, 'on it');
  });
}
